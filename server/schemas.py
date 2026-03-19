from pydantic import BaseModel, Field, field_validator
import html


def _sanitize_language(v: str) -> str:
    v = v.strip().lower()
    if not all(c.isalnum() or c == '-' for c in v):
        return "en"
    return v


class RoomCreate(BaseModel):
    name: str | None = Field(default=None, max_length=50)

    @field_validator('name')
    @classmethod
    def sanitize_name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        if not v:
            return None
        return html.escape(v)


class UserRegister(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    language: str = Field(default="en", max_length=10)

    @field_validator('name')
    @classmethod
    def sanitize_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError('Name cannot be empty')
        return html.escape(v)

    @field_validator('language')
    @classmethod
    def sanitize_language(cls, v: str) -> str:
        return _sanitize_language(v)


class UserJoin(BaseModel):
    userId: str = Field(..., max_length=20)


class ThreadCreate(BaseModel):
    user1_id: str = Field(..., max_length=20)
    user2_id: str = Field(..., max_length=20)
