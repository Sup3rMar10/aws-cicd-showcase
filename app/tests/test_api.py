import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_version_defaults_to_dev():
    assert client.get("/version").json() == {"version": "dev"}


def test_hello():
    assert client.get("/hello/World").json() == {"message": "Hello, World!"}


@pytest.mark.parametrize("bad", ["a" * 51, "x%3Cscript%3E", "a.b"])
def test_hello_rejects_odd_names(bad):
    assert client.get(f"/hello/{bad}").status_code == 422
