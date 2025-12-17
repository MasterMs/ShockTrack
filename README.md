# ShockTrack  
**Low-Cost IoT Suspension Monitoring & Analytics System**

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/1fe556fd-91a7-4e11-816b-a8691541a7eb" />


<img width="1920" height="1040" alt="image" src="https://github.com/user-attachments/assets/04a28471-784e-41e0-b0cf-11bbbeddacf7" />

<img width="1361" height="680" alt="image" src="https://github.com/user-attachments/assets/30998304-9af7-4f2a-a758-f328e75943ae" />

<img width="352" height="771" alt="image" src="https://github.com/user-attachments/assets/ea18f285-784e-40d3-907d-498bb0cfb2c4" />





ShockTrack is an **IoT-based suspension monitoring and analytics platform** designed to retrofit modern suspension telemetry onto legacy vehicles using low-cost hardware. It enables real-time suspension data capture, visualization, logging, and future machine-learning-driven analysis—without relying on proprietary OEM systems.

This project was developed as a **Capstone Project** for the *Honours Bachelor of Computer Science (Mobile Computing)* program at Sheridan College.

---

## 🚗 Motivation

Modern vehicles increasingly ship with advanced suspension telemetry and tuning systems, but these technologies remain:
- **Proprietary**
- **Expensive**
- **Inaccessible to enthusiasts and grassroots motorsport**

ShockTrack addresses this gap by providing:
- High-fidelity suspension data
- Commodity hardware
- Open, extensible architecture
- Support for classic and modified vehicles

---

## 🧠 Core Idea

By mounting **MPU-6050 IMU sensors** directly to suspension components and streaming data via an **ESP32 → Raspberry Pi gateway**, ShockTrack captures real suspension motion (bump & rebound) in real time. This data can then be:
- Visualized live
- Logged to CSV
- Uploaded for analysis
- Used to train ML models for tuning insights

---

## 🏗️ System Architecture

### Hardware (On-Vehicle)
- **MPU-6050** IMU (accelerometer + gyroscope)
- **ESP32** microcontroller
- **3D-printed ABS enclosure**
- Wired serial connection (USB / UART)

### Gateway
- **Raspberry Pi** (or laptop)
- Python-based serial logger
- WebSocket server for real-time streaming
- CSV data logging

### Client
- Mobile app (iOS / Android – planned)
- Web dashboard
- Live telemetry visualization
- Session playback

### Cloud (Planned)
- Session storage (raw + derived data)
- Machine learning pipelines
- Community sharing & comparison
- Authentication and user profiles


---

## ⚙️ Key Features

### Live Telemetry
- Real-time acceleration & vibration data
- Sub-500ms latency via wired serial
- WebSocket streaming

### Data Logging
- Persistent CSV session recording
- Timestamped at gateway level
- Suitable for ML training

### Suspension Analytics (Planned)
- Ride smoothness (RMS acceleration)
- Oscillation & settling behavior
- Understeer / oversteer detection
- Crash & anomaly detection

### Community Sharing (Planned)
- Upload sessions and tunes
- Compare setups across vehicles
- Community-driven optimization

---

## 🤖 Machine Learning Direction

Initial ML experiments (using public datasets) validated the analytics approach:

| Algorithm | Accuracy |
|---------|----------|
| Random Forest | 0.99 |
| KNN | 0.98 |
| Logistic Regression | 0.86 |

Planned ML objectives:
- Suspension mode classification (Eco / Normal / Sport)
- Damping effectiveness analysis
- Anomaly detection
- Driving style inference

---

## 🧪 Validation & Results

- Wired serial communication **eliminated BLE latency issues**
- Improved mounting design significantly reduced sensor noise
- Real vehicle testing demonstrated:
  - Clean acceleration signals
  - Repeatable suspension motion patterns
  - Suitability for high-frequency analysis

---

## 🛠️ Tech Stack

**Hardware**
- ESP32
- MPU-6050
- Raspberry Pi

**Backend**
- Python
- FastAPI
- WebSockets
- CSV logging

**Data / ML**
- NumPy
- Pandas
- scikit-learn
- PyCaret (planned)
- TensorFlow (planned)

**Mobile / Frontend (Planned)**
- SwiftUI
- React
- Firebase / Cloud backend

---

## 📈 Project Roadmap

- ✅ Single-sensor prototype
- ✅ Wired serial data pipeline
- ✅ Live streaming & logging
- 🔄 Multi-wheel sensor deployment
- 🔄 Cloud integration
- 🔄 ML-based tuning recommendations
- 🔄 Community data platform

---

## 👥 Team

- **Marco Siciliano**  
  Honours BCS (Mobile Computing)  
  Sheridan College  

- **Nicholas Sullivan**  
  Honours BCS (Mobile Computing)

- **Kyelle Bantog**  
  Honours BCS (Mobile Computing)

**Supervisor:**  
Dr. Mouhamed Abdulla

---

## 📄 Academic Context

This repository supports the ShockTrack Capstone Project and reflects both:
- Applied computer science (IoT, ML, cloud)
- Real-world automotive engineering constraints

---

## 🔒 Disclaimer

ShockTrack is a **research and prototyping platform**. It is not intended to replace professional motorsport telemetry systems or OEM safety systems.



