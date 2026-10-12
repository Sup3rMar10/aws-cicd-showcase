"""A deliberately tiny service. The interesting part of this repo is the pipeline around it."""
import os

from fastapi import FastAPI, Path

APP_VERSION = os.getenv("APP_VERSION", "dev")  # baked into the image at build time (the git SHA in CI)

app = FastAPI(title="AWS Showcase API", version=APP_VERSION)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/version")
def version():
    return {"version": APP_VERSION}


@app.get("/hello/{name}")
def hello(name: str = Path(min_length=1, max_length=50, pattern=r"^[A-Za-z0-9 _-]+$")):
    return {"message": f"Hello, {name}!"}
