# Dots

<img src="https://github.com/franpitri/dotfiles/blob/master/screenshot.png" width="800">

The dotfiles are configured based on [Regolith-linux](https://regolith-linux.org/) V1.4.1

They can be configured as follows:

```sh
URL=https://gist.githubusercontent.com/FranPitri/cee286db031488cd83e02edfcd10432b/raw/937285b2feac4c82d291d774d3c04f9de7251a65/regolith_setup.sh && \
wget $URL && \
chmod +x regolith_setup.sh
```

After that, run `./regolith_setup.sh`

Once the installation is finished, run the following commands to set zsh as the default shell:

```sh
sudo passwd root && \
chsh -s $(which zsh)
```

Then reboot for changes to take effect. To finish the process, download:

```sh
URL=https://gist.githubusercontent.com/FranPitri/cee286db031488cd83e02edfcd10432b/raw/937285b2feac4c82d291d774d3c04f9de7251a65/regolith_after_setup.sh && \
wget $URL && \
chmod +x regolith_after_setup.sh
```

And run `./regolith_after_setup.sh`