# CampusCoin Smart Contract

## Project Structure

* `contracts/`: Default Contract Folder used by HardHat;
    * `CampusCoin.sol`: Smart Contract file
* `test/`: Default Test Folder used by HardHat;
    * `CampusCoin.js`: Test file
* `hardhat-config.js`: HardHat configuration file
* `sumo-config.js`: SuMo configuration file
* `sumo-results/results/`: The results of SuMo on CampusCoin
    * `mutations.json`: Generated mutations with their details and results
    * `index.html`: A html report for viewing the mutations
* `package.json`: Node project metadata

## Prerequisites
To interact with the project, you must install:
* NodeJS
* npm

Then, install the project dependencies with `npm install`.

## Useful Commands

### HardHat
* Compilng the Smart Contract: `npx hardhat compile`
* Running the tests on the Smart Contract: `npx hardhat test`

### SuMo
* Generating the mutants: `npx sumo lookup`
* Running the tests on all mutants: `npx sumo test`
* Running the tests on a specific mutant: `npx sumo test <mutantHash>`

For more details, check out the [SuMo documentation](https://github.com/MorenaBarboni/SuMo-SOlidity-MUtator): 