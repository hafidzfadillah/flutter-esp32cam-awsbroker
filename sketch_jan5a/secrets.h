#include <pgmspace.h>

#define SECRET
#define THINGNAME "MyNewESP32"

const char WIFI_SSID[] = "WIFI_SSID";
const char WIFI_PASSWORD[] = "WIFI_PASSWORD";

const char AWS_IOT_ENDPOINT[] = "a3gp8u25bug8q8-ats.iot.ap-southeast-1.amazonaws.com";
const char *imgEndpoint = "https://iot-smart-coor-c7780434f6de.herokuapp.com/api/log-capture";
const char *lockEndpoint = "https://iot-smart-coor-c7780434f6de.herokuapp.com/api/log-lock";
const char *rfidEndpoint = "https://iot-smart-coor-c7780434f6de.herokuapp.com/api/log-rfid";

// Amazon Root CA 1
static const char AWS_CERT_CA[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
xxxxxxxxxxxxxxxxxxxxx
-----END CERTIFICATE-----
)EOF";

// Device Certificate
static const char AWS_CERT_CRT[] PROGMEM = R"KEY(
-----BEGIN CERTIFICATE-----
xxxxxxxxxxxxxxxxxxxxx
-----END CERTIFICATE-----
)KEY";

// Device Private Key
static const char AWS_CERT_PRIVATE[] PROGMEM = R"KEY(
-----BEGIN RSA PRIVATE KEY-----
xxxxxxxxxxxxxxxxxxxxx
-----END RSA PRIVATE KEY-----
)KEY";
