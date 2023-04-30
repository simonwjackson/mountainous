{ config, pkgs, ... }:
{
  services.create_ap = {
    enable = false;
    settings = {
      FREQ_BAND = 5;
      HT_CAPAB = "[HT20][HT40-][HT40+][SHORT-GI-20][SHORT-GI-40][TX-STBC][MAX-AMSDU-7935][DSSS_CCK-40][PSMP]";
      VHT_CAPAB = "[MAX-MPDU-11454][RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][MAX-A-MPDU-LEN-EXP0]";
      IEEE80211AC = true;
      IEEE80211N = true;
      GATEWAY = "192.18.5.1";
      PASSPHRASE = "asdfasdfasdf";
      INTERNET_IFACE = "wlp0s20f0u3";
      WIFI_IFACE = "wlp0s20f3";
      SSID = "hopstop";
    };
  };
}
