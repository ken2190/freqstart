<div id="top"></div>

<!-- FREQSTART -->
# freqstart

Freqstart simplifies the usage of freqtrade with NostalgiaForInfinity strategies.
Just copy your commands into a text file and freqstart will take care of the rest.
Freqstart will start your bots in separate TMUX sessions and will try to restart them after a system reboot. 

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- DISCLAIMER -->
## Disclaimer
 
This software is for educational purposes only. Do not risk money which you are afraid to lose. USE THE SOFTWARE AT YOUR OWN RISK. THE AUTHORS AND ALL AFFILIATES ASSUME NO RESPONSIBILITY FOR YOUR TRADING RESULTS.

<!-- GETTING STARTED -->
## Getting Started

Freqstart will install freqtrade and the necessary NostalgiaForInfinity strategies and configs automatically.
With many more "QoL" features tailored to harness the power of freqtrade and community tested extensions.

If you are not familiar with freqtrade, please read the complete documentation first on [freqtrade.io](https://www.freqtrade.io/).

### Prerequisites

  ```sh
  WARNING: Freqstart automatically installs packages and server configurations tailored to freqtrade's needs. It is recommended to set it up in a new and clean environment!
  ```

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

<p align="right">(<a href="#top">back to top</a>)</p>