# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all: clean install build foundry-test

# Clean the repo
clean  :; forge clean

# Install the Modules
install :; forge install --no-commit

# Update Dependencies
update:; forge update

# Builds
build  :; forge build --via-ir

# chmod scripts
scripts :; chmod +x ./scripts/*

# Tests
# --ffi # enable if you need the `ffi` cheat code on HEVM
foundry-test :; forge clean && forge test --optimize --optimizer-runs 200 --via-ir -v

# Run solhint
solhint :; solhint -f table "{contracts,test,scripts}/**/*.sol"

# slither
# to install slither, visit [https://github.com/crytic/slither]
slither :; slither . --fail-low

# Lints
lint :; npx prettier --write "{contracts,test,scripts}/**/*.{sol,ts}"

# Generate Gas Snapshots
snapshot :; forge clean && forge snapshot
