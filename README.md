# openbuild-contracts

## Docs

- [Contract Design](https://app.heptabase.com/w/d996e9ee10666fdc0ebeeebf614665534bdc57ea89b6fff104dc8db924276462?id=b5527e3d-fbef-46a2-a953-020dd9ba0e92)
- [Contract Docs](https://openbuild-contracts.pseudoyu.com/)

## Contract

### Sepolia

- SkillsHub: `0x6D9964EBe1E9E9e7b45E8A3112a29b82bF9Cc08E`
- OpenBuildToken: `0x521FD468fBba8d929bf22F3031b693A499841E55`

## Deploy

### copy .env.example to .env

```bash
cp .env.example .env
```

### set .env

```text
ETHERSCAN_API_KEY=YOUR KEY HERE
INFURA_API_KEY=YOUR KEY HERE
PRIVATE_KEY=YOUR KEY HERE
```

### deploy skillsHub to testnet(sepolia)

```bash
yarn hardhat run scripts/deploySkillsHub.ts --network sepolia
```

### verify skillsHub

```bash
yarn hardhat verify --network sepolia <Contract Address Here>
```

### Deploy OpenBuildToken to testnet(sepolia)

```bash
yarn hardhat run scripts/deployOpenBuildToken.ts --network sepolia
```
