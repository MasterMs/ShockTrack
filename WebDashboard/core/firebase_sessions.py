"""Firebase Auth verification and per-user CSV session storage.

Configure FIREBASE_DATABASE_URL, FIREBASE_STORAGE_BUCKET and either
GOOGLE_APPLICATION_CREDENTIALS or Application Default Credentials.
Never put the service account key in the iOS app or Git repository.
"""
import os

import firebase_admin
from firebase_admin import auth, credentials, db, storage


class FirebaseSessionStore:
    def __init__(self, app):
        self.app = app

    @classmethod
    def from_environment(cls):
        database_url = os.getenv("FIREBASE_DATABASE_URL")
        storage_bucket = os.getenv("FIREBASE_STORAGE_BUCKET")
        if not database_url or not storage_bucket:
            return None

        key_file = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        credential = (
            credentials.Certificate(key_file)
            if key_file
            else credentials.ApplicationDefault()
        )
        app = firebase_admin.initialize_app(
            credential,
            {"databaseURL": database_url, "storageBucket": storage_bucket},
            name="shocktrack-server",
        )
        return cls(app)

    def verify_user(self, id_token: str) -> str:
        # The server must derive the UID from a verified ID token.
        return auth.verify_id_token(id_token, app=self.app)["uid"]

    def upload_session(self, recording) -> str:
        """Store the CSV in Cloud Storage and its index in Realtime Database."""
        path = f"sessions/{recording.uid}/{recording.id}.csv"
        blob = storage.bucket(app=self.app).blob(path)
        blob.upload_from_filename(recording.filepath, content_type="text/csv")

        db.reference(
            f"sessions/{recording.uid}/{recording.id}", app=self.app
        ).set(
            {
                "sessionId": recording.id,
                "uid": recording.uid,
                "startedAt": recording.started_at,
                "endedAt": recording.ended_at,
                "sampleCount": recording.samples,
                "storagePath": path,
                "status": "complete",
            }
        )
        return path
