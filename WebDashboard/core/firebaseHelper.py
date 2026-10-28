
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, storage, firestore


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
        """Upload a CSV to Cloud Storage and register the session in Firestore."""

        file = Path(file_path)

        if not file.is_file():
            raise FileNotFoundError(f"CSV not found: {file_path}")

        if file.suffix.lower() != ".csv":
            raise ValueError("File must be a CSV")

        if not user_id or user_id in (".", "..") or "/" in user_id or "\\" in user_id:
            raise ValueError("Invalid Firebase user ID")

        # Generate session ID
        session_id = self.create_session_id(user_id, file.name)

        # Firebase Cloud Storage path
        storage_path = f"users/{user_id}/sessions/{session_id}"

        # Upload CSV to object storage
        blob = self.bucket.blob(storage_path)
        blob.upload_from_filename(
            str(file),
            content_type="text/csv",
            if_generation_match=0
        )

        # Save recording metadata in Firestore
        session_data = {
            "sessionId": session_id,
            "userId": user_id,
            "fileName": file.name,
            "csvPath": storage_path,
            "uploadedAt": firestore.SERVER_TIMESTAMP
        }

        self.db.collection("users") \
            .document(user_id) \
            .collection("sessions") \
            .document(session_id) \
            .set(session_data)

        return {
            "sessionId": session_id,
            "storagePath": storage_path
        }


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
