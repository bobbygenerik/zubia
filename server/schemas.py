from pydantic import BaseModel, Field, field_validator
import html

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


class UserJoin(BaseModel):
    name: str | None = Field(default=None, max_length=50)
    language: str = Field(default="en", max_length=10)

    @field_validator('name')
    @classmethod
    def sanitize_name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        if not v:
            return None
        return html.escape(v)

    @field_validator('language')
    @classmethod
    def sanitize_language(cls, v: str) -> str:
        v = v.strip().lower()
        # Basic validation for language code (e.g. 'en', 'es', 'pt-br')
        # Just ensure it's alphanumeric and dashes
        if not all(c.isalnum() or c == '-' for c in v):
            return "en"
        return v
