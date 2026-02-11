import os
import json
from datetime import date
from contextlib import asynccontextmanager

import bcrypt
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr
from azure.storage.filedatalake import DataLakeServiceClient
from azure.core.exceptions import ResourceNotFoundError, ResourceExistsError  # type: ignore

# -----------------------
# Config
# -----------------------

FILE_SYSTEM_NAME = "memento-users"  # like a top-level container for users
DIRECTORY_NAME = "users"            # subdirectory inside that file system


def get_service_client() -> DataLakeServiceClient:
    """
    Build a DataLakeServiceClient from the connection string in env.
    """
    # App Service "Application settings" -> AZURE_STORAGE_CONNECTION_STRING
    # App Service "Connection strings" -> CUSTOMCONNSTR_AZURE_STORAGE_CONNECTION_STRING
    conn_str = (
        os.getenv("AZURE_STORAGE_CONNECTION_STRING")
        or os.getenv("CUSTOMCONNSTR_AZURE_STORAGE_CONNECTION_STRING")
    )
    if not conn_str:
        raise RuntimeError(
            "Storage connection string is missing. Set "
            "AZURE_STORAGE_CONNECTION_STRING in App Service Environment variables."
        )
    return DataLakeServiceClient.from_connection_string(conn_str)


service_client = get_service_client()
file_system_client = service_client.get_file_system_client(FILE_SYSTEM_NAME)
directory_client = file_system_client.get_directory_client(DIRECTORY_NAME)


# -----------------------
# Pydantic models
# -----------------------

class SignupRequest(BaseModel):
    name: str
    email: EmailStr
    password: str
    dob: date


class SigninRequest(BaseModel):
    email: EmailStr
    password: str


class SigninResponse(BaseModel):
    token: str

class ProfileResponse(BaseModel):
    name: str
    email: EmailStr
    dob: str   # ISO8601 full-date string
    
# -----------------------
# Storage helpers
# -----------------------

def ensure_filesystem_and_directory():
    """
    Ensure file system and directory exist in ADLS.
    Called on startup.
    """
    # Create file system if needed
    try:
        file_system_client.create_file_system()
    except ResourceExistsError:
        pass

    # Create directory if needed
    try:
        directory_client.create_directory()
    except ResourceExistsError:
        pass


def user_file_client(email: str):
    """
    Return a file client for the given email.
    We use "<email>.json" as file name.
    """
    file_name = f"{email}.json"
    return directory_client.get_file_client(file_name)


def user_exists(email: str) -> bool:
    """
    Check if a user file already exists.
    """
    fc = user_file_client(email)
    try:
        fc.get_file_properties()
        return True
    except ResourceNotFoundError:
        return False


def write_user_record(data: dict):
    """
    Write the user JSON to ADLS as <email>.json.
    Overwrites existing file if needed.
    """
    email = data["email"]
    fc = user_file_client(email)

    content = json.dumps(data)

    # Create file (no-op if already exists, but we control that)
    fc.create_file()

    # Append full content and flush
    fc.append_data(data=content, offset=0, length=len(content))
    fc.flush_data(len(content))


def read_user_record(email: str) -> dict:
    """
    Read user JSON from ADLS.
    Raises ResourceNotFoundError if not found.
    """
    fc = user_file_client(email)
    download = fc.download_file()
    raw = download.readall()
    return json.loads(raw)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Make sure ADLS containers & directories exist at startup
    ensure_filesystem_and_directory()
    yield


app = FastAPI(title="Memento Auth API", lifespan=lifespan)


# -----------------------
# Endpoints
# -----------------------

@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/signup")
def signup(req: SignupRequest):
    # 1. Check if user already exists
    if user_exists(req.email):
        # IMPORTANT: message must include this string for iOS to detect
        raise HTTPException(status_code=400, detail="User already exists")

    # 2. Hash password
    pw_hash = bcrypt.hashpw(req.password.encode("utf-8"), bcrypt.gensalt()).decode(
        "utf-8"
    )

    # 3. Build user record
    record = {
        "name": req.name,
        "email": req.email,
        "dob": str(req.dob),
        "password_hash": pw_hash,
    }

    # 4. Write to ADLS
    write_user_record(record)

    # 5. Minimal success response
    return {"ok": True}


@app.post("/signin", response_model=SigninResponse)
def signin(req: SigninRequest):
    # 1. Try to read user record
    try:
        stored = read_user_record(req.email)
    except ResourceNotFoundError:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # 2. Compare password hashes
    stored_hash = stored.get("password_hash", "").encode("utf-8")
    if not bcrypt.checkpw(req.password.encode("utf-8"), stored_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # 3. Create a dummy token (later you can use JWTs)
    token = f"dummy-token-for-{req.email}"
    return SigninResponse(token=token)


@app.get("/profile", response_model=ProfileResponse)
def get_profile(email: EmailStr):
    """
    Return basic profile info (name, email, dob) for the given email.
    Reads from the same JSON we write during signup.
    """
    try:
        record = read_user_record(email)
    except ResourceNotFoundError:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Avoid sending password_hash back
    name = record.get("name", "")
    dob = record.get("dob", "")

    return ProfileResponse(name=name, email=email, dob=dob)
