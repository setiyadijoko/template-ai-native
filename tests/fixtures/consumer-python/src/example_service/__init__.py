from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str


def health_response() -> HealthResponse:
    return HealthResponse(status="ok")
