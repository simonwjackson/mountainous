{host, ...}: {
  device = {
    id = "HPM2RXN-G2MQWQC-FFGBPRM-TK2JIZT-QZM4JUF-SS2HFCC-EULK4W4-3ZUV6QU";
    name = "Laptop (${host})";
  };
  shares = {
    notes = {
      path = "/snowscape/notes";
      type = "sendreceive";
      versioning = {
        type = "simple";
        params.keep = "20";
      };
    };
  };
}