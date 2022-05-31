<div id="top"></div>

<!-- FREQSTART -->
# FREQSTART

Freqstart simplifies the usage of freqtrade with NostalgiaForInfinity strategies.
Just copy your commands into a text file and freqstart will take care of the rest.
Freqstart will start your bots in separate TMUX sessions and will try to restart them after a system reboot.
You could start a hundred bots with different strategies and versions in one click.

![Freqstart Screen Shot][product-screenshot]

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- DISCLAIMER -->
## Disclaimer
 
This software is for educational purposes only. Do not risk money which you are afraid to lose. USE THE SOFTWARE AT YOUR OWN RISK. THE AUTHORS AND ALL AFFILIATES ASSUME NO RESPONSIBILITY FOR YOUR TRADING RESULTS.

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

Freqstart will install freqtrade and the necessary NostalgiaForInfinity strategies and configs automatically.
With many more "QoL" features tailored to harness the power of freqtrade and community tested extensions.

If you are not familiar with freqtrade, please read the complete documentation first on [freqtrade.io](https://www.freqtrade.io/).

### Prerequisites

`WARNING:` Freqstart automatically installs packages and server configurations tailored to freqtrade's needs. It is recommended to set it up in a new and clean environment!

This project is beeing developed and testet on Vultr "Tokyo" Server with Debian.

Get closer to Binance? Try Vultr "Tokyo" Server and get $100 usage for free:<br/>
[https://www.vultr.com/?ref=9122650-8H](https://www.vultr.com/?ref=9122650-8H)

### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/berndhofer/freqstart.git
   ```
2. Change directory to `freqstart`
   ```sh
   cd ~/freqstart
   ```
3. Make `freqstart.sh` executable
   ```sh
   sudo chmod +x freqstart.sh
   ```
4. Run `freqstart.sh`
   ```sh
   ./freqstart.sh
   ```
5. Edit `autostart.txt` and run `freqstart.sh` again
   ```txt
   vi ./autostart.txt
   ```
6. Run `freqstart.sh -a` to automatically restart all bots
   ```sh
   ./freqstart.sh -a
   ```
7. Run `freqstart.sh -k` to disable all non protected bots and restart service
   ```sh
   ./freqstart.sh -k
   ```
8. Run `freqstart.sh -h` for more infos
   ```sh
   ./freqstart.sh -h
   ```
   
### Autostart

1. bot command has to start with _freqstart_ and the rest will be ignored
2. you can use any symbol to exclude lines but preferably use the hastag
3. always use absolute paths to strategies and configs
4. keep the proxy.json always at the end of the line or remove it for certain bots
5. add your strategies and configs with api keys at the end of the line but before proxy.json
6. database URL names starting with "live" or "protected" will NOT be restartet or terminated in any condition
7. freqstart only manages the installation and start of bots and no files and functions are altered
8. read the disclaimer...

#### Example `autostart.txt` - Do not forget to change the version numbers!
   ```txt
   freqtrade trade --dry-run --db-url sqlite:///example-dryrun.sqlite --strategy=NostalgiaForInfinityX --strategy-path=/root/freqstart/NostalgiaForInfinity_v00.0.000 -c=/root/freqstart/NostalgiaForInfinity_v00.0.000/configs/pairlist-volume-binance-usdt.json -c=/root/freqstart/NostalgiaForInfinity_v00.0.000/configs/blacklist-binance.json -c=/root/freqstart/NostalgiaForInfinity_v00.0.000/configs/exampleconfig.json -c=/root/freqstart/proxy.json
   # some comment will be ignored
   freqtrade trade --dry-run --db-url sqlite:///example2.sqlite --strategy=NostalgiaForInfinityX --strategy-path=/root/freqstart/NostalgiaForInfinity_v00.0.000 -c=/root/freqstart/everything-in-one-config.json
   ```

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- ROADMAP -->
## Roadmap

See the [open issues](https://github.com/berndhofer/freqstart/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- Support -->

## Support

Since this is a small project where I taught myself some bash scripts, you are welcome to improve the code. If you just use the script and like it, remember that it took a lot of time, testing and also money for infrastructure. You can contribute by donating to the following wallets. Thank you very much for that!

* `BTC` 1M6wztPA9caJbSrLxa6ET2bDJQdvigZ9hZ
* `ETH` 0xb155f0F64F613Cd19Fb35d07D43017F595851Af5
* `BSC` 0xb155f0F64F613Cd19Fb35d07D43017F595851Af5

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[product-screenshot]: images/screenshot.png