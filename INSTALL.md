# Install modules

SDK installed in TOIT_SDK_HOME

- requires mqtt library - `jag pkg install github.com/toitware/mqtt`
- requires ntp library - `jag pkg install github.com/toitlang/pkg-ntp`


Prepping device:

```
TOIT_SDK_HOME=$HOME/code/toit/toit
$TOIT_SDK_HOME/build/host/sdk/tools/assets -e device.assets create
$TOIT_SDK_HOME/build/host/sdk/tools/assets -e device.assets add config device.json
jag flash --name device-lights
jag container install --device bendeviceedikt-lights --assets=device.assets light-monitor light-monitor.toit
```
