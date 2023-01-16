# Lights with ESP-32


## Chip Layout

```
 1 GND  TXD  +-----+  RST  GND
 2 IO27 RXD  |     |  SVP  NC
 3 IO25 IO22 |     |  IO26 SVN
 4 IO32 IO21 |     |  IO18 IO35
 5 TDI  IO17 |     |  IO19 IO33
 6 IO4  IO16 |     |  IO23 IO34
 7 IO0  GND  |     |  IO5  TMS
 8 IO2  VCC  |     |  3.3V NC
 9 SD1  TD0  | +-+ |  TCK  SD2
10 CLK  SDD  +-+ +-+  SD3  CMD
```

[https://github.com/artofcircuits/Store/blob/main/WeMOS%20D1%20Mini%20ESP32/WEMOS-D1-MINI-ESP32-SCH.jpg](Diagram)
[https://www.espressif.com/sites/default/files/documentation/esp32-wroom-32_datasheet_en.pdf](ESP-32 WROOM data sheet)

```
ESP 32 WROOM


GPIO0  - IO0 - strapping pin
GPIO1  - TXD
GPIO2  - IO2 - strapping pin
GPIO3  - RXD
GPIO4  - IO4
GPIO5  - IO5 - strapping pin

GPIO6  - CLK
GPIO7  - SDD
GPIO8  - SD1
GPIO9  - SD2
GPIO10 - SD3
GPIO11 - CMD

GPIO12 - TDI - strapping pin
GPIO13 - TCK
GPIO14 - TMS
GPIO15 - TD0 - strapping pin

GPIO16 - IO16
GPIO17 - IO17
GPIO18 - IO18
GPIO19 - IO19

GPIO21 - IO21
GPIO22 - IO22
GPIO23 - IO23

GPIO25 - IO25
GPIO26 - IO26
GPIO27 - IO27

GPIO32 - IO32
GPIO33 - IO33
GPIO34 - IO34
GPIO35 - IO35
GPIO36 - SVP
GPIO39 - SVN
```

Not available: GPIO37, GPIO38


```
3.3V ---[LDR 5528] -+-[10kOhm] - GND
                    |
                   IO32

LEDs

IO16 --[330 Ohm]--|>|-- GND
IO17 --[330 Ohm]--|>|-- GND
IO18 --[330 Ohm]--|>|-- GND
IO19 --[330 Ohm]--|>|-- GND

```

## Software

Asset: JSON stored as "config"

{
  "mqttHost: <mqtt-host>,
  "mqttLogin": <mqtt-login>,
  "mqttPassword": <mqtt-password>,
  "mqttTopic": <mqtt-topic>
}
