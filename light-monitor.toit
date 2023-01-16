//
// Light monitor, version 2
//
// Poll a LDR on an ESP 32, write data to mqtt. 
//

//
// expects JSON asset with configuration under the "config" asset key. Supported keys:
//
//  mqttHost          - string, MQTT server host, needs DNS resolution
//  mqttPort          - int, MQTT server port
//  mqttClientId      - string, MQTT client id
//  mqttUser          - string, MQTT user 
//  mqttPassword      - string, MQTT password
//  mqttTopic         - string, MQTT topic
//  ntpHost           - string NTP server host, needs DNS resolution
//  dnsHosts          - array of strings, DNS hosts for DNS resolution
//  sensorMultiplier  - int, spreads the value range (multiplier for adc.get)
//  sensorOffset      - int, baseline for the value range. Dark should be 0.
//  tickerResolution  - int, frequency in seconds for the ticker
//

import encoding.json
import esp32
import gpio
import gpio.adc
import log
import mqtt
import net
import net.modules.dns
import ntp
import system.assets

// set to log.DEBUG_LEVEL for debugging
LOG ::= log.Logger log.INFO_LEVEL log.DefaultTarget --name="light-monitor"

main:
    // configure gpio LED pins

    // turns on when network connection is established
    network_led := gpio.Pin 16 --output
    network_led.set 0

    // turns on when MQTT is connected
    mqtt_led := gpio.Pin 17 --output
    mqtt_led.set 0

    // turns on when NTP is successful
    ntp_led := gpio.Pin 18 --output
    ntp_led.set 0

    // blink every time a measurement is sent
    sensor_led := gpio.Pin 19 --output
    sensor_led.set 0

    // bring up ADC input pin, start ADC
    ad_pin := gpio.Pin 32
    adc := adc.Adc ad_pin

    // load configuration
    assets := assets.decode
    config/Map := json.decode assets["config"]

    LOG.debug "Config loaded, found $config.keys config keys"

    LOG.info "=================================================="
    LOG.info "="
    LOG.info "= Station Id is        " + config["mqttClientId"]
    LOG.info "= Topic is             " + config["mqttTopic"]
    LOG.info "= Sensor Multiplier is " + config["sensorMultiplier"].stringify
    LOG.info "= Sensor Offset is     " + config["sensorOffset"].stringify
    LOG.info "= Ticker Resolution is " + config["tickerResolution"].stringify
    LOG.info "="
    LOG.info "=================================================="

    
    // bring up network 
    network := net.open

    LOG.debug "Network established"

    network_led.set 1

        // DNS lookup for ntp host
    resolvedNtpHost := dns_resolve config["ntpHost"] 
        --dns_server=config["dnsHosts"][0]
    
    LOG.debug "NTP host resolved to $resolvedNtpHost.stringify"

    task:: ntp_sync resolvedNtpHost
        --led=ntp_led

    // DNS lookup for mqtt host
    resolvedMqttHost := dns_resolve config["mqttHost"] 
        --dns_server=config["dnsHosts"][0]
    
    LOG.debug "MQTT host resolved to $resolvedMqttHost.stringify"

    // establish mqtt connection
    client := mqtt_connect network resolvedMqttHost.stringify config["mqttPort"]
        --clientId=config["mqttClientId"]
        --userName=config["mqttUser"]
        --password=config["mqttPassword"]
        --led=mqtt_led

    sensor_multiplier := config["sensorMultiplier"]
    sensor_offset     := config["sensorOffset"]
    tick_in_ms := config["tickerResolution"] * 1000

    count := 0
    ledToggle := 1
    
    while true:
        time := Time.now
        sensor := ((adc.get * sensor_multiplier) + sensor_offset).to_int

        if sensor < 0:
            // sensor result of -x means that the offset needs to be x bigger
            // offset - (-x) == offset + x            
            LOG.warn "Sensor value < 0 ($sensor), correcting!"
            sensor_offset -= sensor            
            sensor = 0
            LOG.warn "Sensor offset now $sensor_offset, update config!"

        data := {
            "sensor": sensor,
            "time": time.utc.stringify,
            "count": count++,
            "station": config["mqttClientId"]
        }

        payload := json.encode data

        LOG.debug "Payload: $payload.to_string"

        mqtt_send client config["mqttTopic"] payload
        
        // blink led
        sensor_led.set 1
        sleep --ms=500
        sensor_led.set 0

        // get as close to the tick interval as possible
        elapsed_time := time.to Time.now
        wait_time_in_ms := tick_in_ms - elapsed_time.in_ms

        // clamp to tick time if out of bounds
        if wait_time_in_ms < 0 or wait_time_in_ms > tick_in_ms:
            wait_time_in_ms = tick_in_ms

        sleep --ms=wait_time_in_ms

//
// end of main program
//

//
// Do DNS resolution. This is done manually as the builtin resolution
// (as of 2.0.0-alpha-47) goes straight to the google 8.8.8.8 resolvers
// and does not respect local DNS (as delivered by DHCP). This should be 
// better at some point (monitor https://github.com/toitlang/toit/discussions/1333)
//
dns_resolve host/string -> net.IpAddress
    --dns_server/string:
    dns_exception := catch --trace:
        return dns.dns_lookup host
            --server=dns_server
            --accept_ipv4=true
            --accept_ipv6=false

    if dns_exception:
        exception_recovery "Could not resolve host name: $host"

    unreachable

//
// connect a client to mqtt
//
mqtt_connect network/net.Interface -> mqtt.Client
    host/string 
    port/int 
    --clientId/string
    --userName/string
    --password/string
    --led/gpio.Pin:

    client := null
    mqtt_exception := catch --trace:
        transport := mqtt.TcpTransport network 
            --host=host
            --port=port
        client = mqtt.Client --transport=transport  --logger=LOG

        options := mqtt.SessionOptions
            --clean_session
            --client_id=clientId
            --username=userName
            --password=password

        client.start --options=options
        LOG.debug "MQTT connection to $host established"
        led.set 1

        return client

    if mqtt_exception:
        exception_recovery "Could not connect to MQTT host $host"
    unreachable


//
// send payload out
//
mqtt_send client/mqtt.Client topic/string payload/ByteArray:
        publish_exception := catch --trace:
            client.publish topic payload
            return

        if publish_exception:
            exception_recovery "Lost connection to MQTT client"
        unreachable

//
// exception "recovery". This uses the fact that any deep sleep will
// restart the program from main. There is not a lot to recover,
// if DNS resolution or MQTT connect fails, simply crash and restart.
//
// good enough. :-)
//
exception_recovery msg/string -> none
    --duration_in_sec/int = 5:
    LOG.error msg
    // deep sleep, will restart
    sleep --ms=duration_in_sec * 1000
    esp32.deep_sleep (Duration --s=duration_in_sec)

//
// Background task that sets the local time
//
ntp_sync host/net.IpAddress -> none
    --led/gpio.Pin:

    while true:
        result ::= ntp.synchronize --server=host.stringify
        if result:
            LOG.debug "NTP: $result.adjustment ±$result.accuracy"
            esp32.adjust_real_time_clock result.adjustment

            // blip LED for 500ms to show that NTP was done. LED is
            // on afterwards.
            led.set 0
            sleep --ms=500
            led.set 1
            // established time, sleep for an hour
            sleep --ms=3_599_500
        else:
            // error, sleep for a minute, retry
            led.set 0
            sleep --ms=59_500