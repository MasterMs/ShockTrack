#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>

Adafruit_MPU6050 mpu;
bool headerPrinted = false;

void setup() {
  Serial.begin(115200);
  while (!Serial) { delay(10); }

  if (!mpu.begin()) {
    Serial.println("Failed to find MPU6050 chip");
    while (1) { delay(10); }
  }

  // Configure MPU6050 ranges
  mpu.setAccelerometerRange(MPU6050_RANGE_4_G); // +/- 4x gravitational constant
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  mpu.setFilterBandwidth(MPU6050_BAND_260_HZ);
  delay(100);
}

void loop() {
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  // Print CSV header once
  if (!headerPrinted) {
    Serial.println("acel_x, acel_y, acel_z, gyro_x, gyro_y, gyro_z");
    headerPrinted = true;
  }

  // a.acceleration.x -= 0.1540;
  // a.acceleration.y -= 0.1890;
  // a.acceleration.z += 0.7565;

  g.gyro.x += 0.04;
  g.gyro.y -= 0.09;
  g.gyro.z += 0.13;


  // CSV row (2 decimal places; accel in m/s^2, gyro in rad/s per Adafruit API)
  Serial.print(a.acceleration.x, 2); Serial.print(", ");
  Serial.print(a.acceleration.y, 2); Serial.print(", ");
  Serial.print(a.acceleration.z, 2); Serial.print(", ");
  Serial.print(g.gyro.x, 2);         Serial.print(", ");
  Serial.print(g.gyro.y, 2);         Serial.print(", ");
  Serial.println(g.gyro.z, 2);

  delay(20); // ~50 Hz
}
