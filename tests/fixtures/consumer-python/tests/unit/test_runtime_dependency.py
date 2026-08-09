from fastapi import FastAPI

from example_service import HealthResponse, health_response


def test_health_contract_uses_runtime_dependencies() -> None:
    app = FastAPI()
    app.get("/health", response_model=HealthResponse)(health_response)

    assert any(route.path == "/health" for route in app.routes)
    assert health_response() == HealthResponse(status="ok")
