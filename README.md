# gddns2

An DDNS client for Gehirn DNS of [Gehirn Infrastructure Service](https://www.gehirn.jp/).

## Usage

1. clone this repository.
2. edit `config.yaml`
3. run `gddns2.rb [ip-addr]`

Caution: gddns2 requires API key/secret with *below permission*

- *Read* of Zones in General Management of DNS
- *Full Access* of zone which you want update by gddns2 in Zones

## Information

This application uses [ipinfo.io](http://ipinfo.io) to get global IP address.


## License

Licensed under MIT License (see LICENSE.md)
