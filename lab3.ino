#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>
#include <ArduinoBLE.h> // Include the Arduino BLE library

Adafruit_MPU6050 mpu;

// Define BLE service and characteristics
BLEService mpuService("180C"); // Custom BLE service UUID
BLECharacteristic accelCharacteristic("2A01", BLERead | BLENotify, 18); // For acceleration (6 floats)
BLECharacteristic gyroCharacteristic("2A02", BLERead | BLENotify, 18);  // For gyroscope (6 floats)

void setup() {
  Serial.begin(115200);
  while (!Serial)
    delay(10); // Wait for Serial monitor to open

  Serial.println("Initializing MPU6050...");
  
  // Initialize MPU6050
  if (!mpu.begin()) {
    Serial.println("Failed to find MPU6050 chip");
    while (1) {
      delay(10);
    }
  }
  Serial.println("MPU6050 Found!");

  // Configure MPU6050 ranges
  mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  delay(100);

  // Initialize BLE
  if (!BLE.begin()) {
    Serial.println("Failed to initialize BLE!");
    while (1);
  }
  Serial.println("BLE Initialized");

  // Set BLE device name and service
  BLE.setLocalName("MPU6050_BLE");
  BLE.setAdvertisedService(mpuService);

  // Add characteristics to the service
  mpuService.addCharacteristic(accelCharacteristic);
  mpuService.addCharacteristic(gyroCharacteristic);
  BLE.addService(mpuService);

  // Start advertising BLE service
  BLE.advertise();
  Serial.println("BLE Advertising started!");
}

void loop() {
  // BLE peripheral management
  BLEDevice central = BLE.central();

  if (central) {
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    // Loop while central device is connected
    while (central.connected()) {
      // Get new sensor events
      sensors_event_t a, g, temp;
      mpu.getEvent(&a, &g, &temp);

      // Prepare acceleration data (X, Y, Z)
      float accelData[3] = {a.acceleration.x, a.acceleration.y, a.acceleration.z};
      accelCharacteristic.writeValue((byte*)accelData, sizeof(accelData));

      // Prepare gyroscope data (X, Y, Z)
      float gyroData[3] = {g.gyro.x, g.gyro.y, g.gyro.z};
      gyroCharacteristic.writeValue((byte*)gyroData, sizeof(gyroData));

      // Log to Serial for debugging
      Serial.print("Accel: X=");
      Serial.print(a.acceleration.x);
      Serial.print(" Y=");
      Serial.print(a.acceleration.y);
      Serial.print(" Z=");
      Serial.println(a.acceleration.z);

      Serial.print("Gyro: X=");
      Serial.print(g.gyro.x);
      Serial.print(" Y=");
      Serial.print(g.gyro.y);
      Serial.print(" Z=");
      Serial.println(g.gyro.z);

      delay(20); // 50 Hz update rate
    }

    // When disconnected
    Serial.println("Central disconnected");
  }
}
