
from pathlib import Path
from datetime import timedelta

import firebase_admin
from firebase_admin import credentials, storage, firestore, db


class FirebaseHelper:
    def __init__(self, bucket_name: str, credentials_path: str):
        try:
            self.app = firebase_admin.get_app()
        except ValueError:
            cred = credentials.Certificate(credentials_path)
            self.app = firebase_admin.initialize_app(
                cred,
                {"storageBucket": bucket_name}
            )

        self.bucket = storage.bucket(app=self.app)
        self.db = firestore.client(app=self.app)

    @staticmethod
    def create_session_id(user_id: str, filename: str) -> str:
        """Create session ID from Firebase user ID and CSV filename."""
        return f"{user_id}_{filename}"

    def upload_csv(self, file_path: str, user_id: str) -> dict:
        """Upload a CSV file to Firebase Cloud Storage."""

        file = Path(file_path)

        if not file.is_file():
            raise FileNotFoundError(f"CSV not found: {file_path}")

        if file.suffix.lower() != ".csv":
            raise ValueError("File must be a CSV")

        if not user_id or user_id in (".", "..") or "/" in user_id or "\\" in user_id:
            raise ValueError("Invalid Firebase user ID")

        session_id = self.create_session_id(user_id, file.name)
        storage_path = f"users/{user_id}/sessions/{session_id}"

        blob = self.bucket.blob(storage_path)
        blob.upload_from_filename(
            str(file),
            content_type="text/csv",
            if_generation_match=0
        )

        url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=15),
            method="GET"
        )

        return {
            "sessionId": session_id,
            "storagePath": storage_path,
            "fileName": file.name,
            "downloadUrl": url
        }

    def get_user_logs(self, user_id: str) -> list[dict]:
        """List a user's CSV logs with temporary download URLs."""

        if not user_id or user_id in (".", "..") or "/" in user_id or "\\" in user_id:
            raise ValueError("Invalid Firebase user ID")

        prefix = f"users/{user_id}/sessions/"
        logs = []

        for blob in self.bucket.list_blobs(prefix=prefix):
            if not blob.name.lower().endswith(".csv"):
                continue

            session_id = blob.name.rsplit("/", 1)[-1]

            logs.append({
                "sessionId": session_id,
                "storagePath": blob.name,
                "fileName": session_id.removeprefix(f"{user_id}_"),
                "downloadUrl": blob.generate_signed_url(
                    version="v4",
                    expiration=timedelta(minutes=15),
                    method="GET"
                )
            })

        return logs


if __name__ == "__main__":
    # Example usage
    firebase_helper = FirebaseHelper(
        bucket_name="shocktrack_motion_data",
        credentials_path="C:/Users/Marco/Documents/ShockTrack/git/ShockTrack/WebDashboard/shocktrack-512317-c8a483490e28.json"
    )

    try:
        result = firebase_helper.upload_csv(
            "C:/Users/Marco/Documents/ShockTrack/git/ShockTrack/WebDashboard/logs/sensor_output_with_timestamps_20261019-194226.csv", "user123"
        )
        print("Upload successful:", result)
    except Exception as e:
        print("Error:", e)
