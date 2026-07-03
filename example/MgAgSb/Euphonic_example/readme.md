### Running Euphonic for powder-averaged phonon DOS

1. **Install Euphonic**  
   Follow the official instructions at [https://euphonic.readthedocs.io](https://euphonic.readthedocs.io) to install the package.

2. **Run the powder‑map calculation**  
   In the directory that contains your `phonopy.yaml` file, execute the following command:

   ```bash
   euphonic-powder-map --weighting coherent --energy-unit meV --temperature 300.0 --e-min -10 --e-max 42 --q-min 0.2838 --q-max 8.055 --e-i 42 --eb 5.0 --cmap jet phonopy.yaml -s dos --save-json dos.json
