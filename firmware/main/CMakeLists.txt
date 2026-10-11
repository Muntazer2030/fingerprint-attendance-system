idf_component_register(
    SRCS "main.c" "net_eth.c" "evlog.c" "oled.c" "api_server.c" "fpm.c" "users.c" "attend.c" "timesync.c" "cfg.c"
    INCLUDE_DIRS "."
    REQUIRES enc28j60 nvs_flash esp_partition esp_timer esp_app_format esp_driver_i2c esp_eth esp_netif esp_event esp_driver_spi esp_driver_gpio esp_http_server esp_driver_uart esp_driver_ledc mbedtls driver
)
