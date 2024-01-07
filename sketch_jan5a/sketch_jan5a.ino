/////////////////////////////////////////////////////////////////
/*
  AWS IoT | ESP32CAM working as a publisher on MQTT
  Video Tutorial: https://youtu.be/7_3qbou_keg
  Created by Eric N. (ThatProject)
*/
/////////////////////////////////////////////////////////////////

#include "secrets.h"
#include <Arduino.h>
#include <WiFiClientSecure.h>
#include <MQTTClient.h>
#include <HTTPClient.h>
#include <Base64.h>
#include <WiFi.h>
#include "esp_camera.h"

#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

#define ESP32CAM_PUBLISH_TOPIC   "esp32/cam_0"
#define ESP32CAM_SUBSCRIBE_TOPIC "esp32/cam_command"

#define LIGHT_PIN 4
const int PWMLightChannel = 4;

const int bufferSize = 1024 * 23; // 23552 bytes

WiFiClientSecure net = WiFiClientSecure();
MQTTClient client = MQTTClient(bufferSize);

void connectAWS()
{
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.println("\n\n=====================");
  Serial.println("Connecting to Wi-Fi");
  Serial.println("=====================\n\n");

  while (WiFi.status() != WL_CONNECTED){
    delay(500);
    Serial.print(".");
  }

  // Ping a website to check the internet connection
//  Serial.println("Pinging google.com...");
//  WiFi.hostByName("google.com", serverIp);

//  if (serverIp != IPAddress(0, 0, 0, 0)) {
//     Serial.print("IP Address: ");
//     Serial.println(serverIp);
//  } else {
//     Serial.println("Error: Unable to resolve host name");
//  }

  // Configure WiFiClientSecure to use the AWS IoT device credentials
  net.setCACert(AWS_CERT_CA);
  net.setCertificate(AWS_CERT_CRT);
  net.setPrivateKey(AWS_CERT_PRIVATE);

  // Connect to the MQTT broker on the AWS endpoint we defined earlier
  client.begin(AWS_IOT_ENDPOINT, 8883, net);
  client.setCleanSession(true);

  Serial.println("\n\n=====================");
  Serial.println("Connecting to AWS IOT");
  Serial.println("=====================\n\n");

  while (!client.connect(THINGNAME)) {
    Serial.print(".");
    delay(100);
  }

  if(!client.connected()){
    Serial.println("AWS IoT Timeout!");
    ESP.restart();
    return;
  }

  Serial.println("\n\n=====================");
  Serial.println("AWS IoT Connected!");
  Serial.println("=====================\n\n");

  // Subscribe to the command topic
  client.subscribe(ESP32CAM_SUBSCRIBE_TOPIC);
  client.onMessage(messageReceived);
}

void handleCommand(const String &command)
{
  if (command == "capture_image")
  {
    Serial.println("Capturing image...");
    captureAndUploadImage();
  }
  // Add more commands as needed
}

void messageReceived(String &topic, String &payload)
{
  Serial.println("Received message on topic: " + topic + ", payload: " + payload);
  
  if (topic == ESP32CAM_SUBSCRIBE_TOPIC)
  {
    handleCommand(payload);
  }
}

void cameraInit(){
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_VGA; // 640x480
  config.jpeg_quality = 10;
  config.fb_count = 2;

  // camera init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    ESP.restart();
    return;
  }
}

void grabImage(){
  camera_fb_t * fb = esp_camera_fb_get();
  if(fb != NULL && fb->format == PIXFORMAT_JPEG && fb->len < bufferSize){
    Serial.print("Image Length: ");
    Serial.print(fb->len);
    Serial.print("\t Publish Image: ");
    bool result = client.publish(ESP32CAM_PUBLISH_TOPIC, (const char*)fb->buf, fb->len);
    Serial.println(result);

    if(!result){
      ESP.restart();
    }
  }
  esp_camera_fb_return(fb);
  delay(1);
}

void captureAndUploadImage() {
  Serial.println("Capturing image...");

  camera_fb_t *fb = esp_camera_fb_get();
  String imageData((const char *)fb->buf, fb->len);

  Serial.println("Uploading image...");

  HTTPClient http;
  http.begin(imgEndpoint);

  http.addHeader("Content-Type", "multipart/form-data");

  // Add the image data
  http.addHeader("Content-Disposition", "form-data; name=\"image\"; filename=\"image.jpg\"");
  http.addHeader("Content-Length", String(fb->len));

  // Add the 'capture_by' parameter
  http.addHeader("Content-Disposition", "form-data; name=\"capture_by\"");
  http.addHeader("Content-Length", String(strlen("ESP32-CAM")));  // Length of 'capture_by' string
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");

  // Add the image data
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");

  int httpResponseCode = http.POST(imageData);
  if (httpResponseCode >= 300 && httpResponseCode < 400) {
    String newUrl = http.header("Location");
    Serial.print("Redirecting to: ");
    Serial.println(newUrl);

    // You can create a new HTTPClient and send the request to the new URL here
    // Remember to update the 'imgEndpoint' variable with the new URL
  } 

  if (httpResponseCode == 201) {
    Serial.println("Image uploaded successfully!");
  } else {
    Serial.printf("Failed to upload image. HTTP response code: %d\n", httpResponseCode);
    // Print response headers
    String headers = http.getString();
    Serial.println("Response Headers:");
    Serial.println(headers);

    // Print response body
    String response = http.getString();
    Serial.println("Response Body:");
    Serial.println(response);
  }

  // Cleanup
  http.end();
  esp_camera_fb_return(fb);
  delay(5000);  // Adjust as needed

  

  // // Check response
  // if (httpResponseCode == 200) {
  //   Serial.println("Image uploaded successfully!");
  // } else {
  //   Serial.printf("Failed to upload image. HTTP response code: %d\n", httpResponseCode);

    
  // }

  // // Cleanup
  // http.end();
  // esp_camera_fb_return(fb);

  // // Delay before capturing/uploading the next image
  // delay(5000);  // Adjust as needed
}

void setup() {
  //Set up flash light
  ledcSetup(PWMLightChannel, 1000, 8);
  pinMode(LIGHT_PIN, OUTPUT);    
  ledcAttachPin(LIGHT_PIN, PWMLightChannel);
  
  Serial.begin(115200);

  cameraInit();
  connectAWS();
}

void testServerEndpoint() {
  // Replace 'your-api-endpoint' with the actual endpoint of your Laravel API
  String apiUrl = imgEndpoint;

  // Create an HTTP client
  HTTPClient http;

  // Begin the GET request
  http.begin(apiUrl);

  // Send the GET request
  int httpResponseCode = http.GET();

  // Check the response code
  if (httpResponseCode > 0) {
    Serial.println("Server endpoint is accessible.");
    
    Serial.print("HTTP Response code: ");
    Serial.println(httpResponseCode);

    // Get the payload from the server
    String payload = http.getString();
    Serial.println(payload);
  } else {
    Serial.printf("Failed to access server endpoint. HTTP response code: %d\n", httpResponseCode);
  }

  // End the request
  http.end();
}

void loop() {
  client.loop();

  // ledcWrite(PWMLightChannel,50);
  // delay(1000);
  // ledcWrite(PWMLightChannel,0);
  // delay(1000);
  // testServerEndpoint();

  if(client.connected()) grabImage();
}