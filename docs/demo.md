# Demo

## Automated Unichain Demo

The canonical judge/demo runner is:

```bash
make demo-testnet
```

This runs `scripts/demo_fractional.sh`, which:

1. loads `.env` and validates chain/network preflight
2. resolves demo users (`USER_A_PRIVATE_KEY`, `USER_B_PRIVATE_KEY`) and auto-generates fresh EOAs if a key resolves to an on-chain contract account
3. checks whether `TOKEN0_ADDRESS`, `TOKEN1_ADDRESS`, `VAULT_ADDRESS`, and `HOOK_ADDRESS` are already deployed and have bytecode
4. deploys contracts if needed via `script/00_DeployFractionalSystem.s.sol`
5. stores discovered addresses back into `.env`
6. runs lifecycle interactions via `script/02_DemoUnichainLifecycle.s.sol`
7. prints transaction hash explorer URLs for deployment and lifecycle phases
8. prints a final judge summary from on-chain state

No Reactive infrastructure is used or required.

## Lifecycle (User Perspective)

The demo script executes these phases in order:

1. `Owner preflight`
2. `System deployment` (only if missing)
3. `User funding` (Owner funds User A and User B gas)
4. `User A deposit`
5. `User B deposit`
6. `Swap execution + hook fee signal` (`beforeSwap/afterSwap` path exercised)
7. `User A redeem`
8. `Judge summary`

Each phase emits deterministic console logs in-script and prints transaction URLs in the shell wrapper.

Broadcast artifacts are persisted to:

- `broadcast/00_DeployFractionalSystem.s.sol/1301/run-latest.json`
- `broadcast/02_DemoUnichainLifecycle.s.sol/1301/run-latest.json`

## Complete Ordered Transaction Ledger (Unichain Sepolia)

Captured from the broadcast artifacts above on **March 15, 2026 (UTC)**.
Explorer base: `https://sepolia.uniscan.xyz`.

### Phase A: Deployment + Pool Setup (18 tx)

1. [0x22394c577332c3224143643268be94bcf17822ff2d8292b872020249906056ee](https://sepolia.uniscan.xyz/tx/0x22394c577332c3224143643268be94bcf17822ff2d8292b872020249906056ee) - CREATE | MockToken | - | 0x369b5a33e388a631f056e6a398927008ca4c5660
2. [0xc6a7b6f94dfcdca1f9ab743e02d54305e2df10a7823b046457db626fde204a35](https://sepolia.uniscan.xyz/tx/0xc6a7b6f94dfcdca1f9ab743e02d54305e2df10a7823b046457db626fde204a35) - CREATE | MockToken | - | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
3. [0x9c7ae019b23a8e2d1968f4f3143f0d440855aa95c36b5b420b50608592702423](https://sepolia.uniscan.xyz/tx/0x9c7ae019b23a8e2d1968f4f3143f0d440855aa95c36b5b420b50608592702423) - CALL | MockToken | mint(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
4. [0x2a11918033089a3cf50182ef89966dd2c2bb3796d7bb1487f277c5749472478f](https://sepolia.uniscan.xyz/tx/0x2a11918033089a3cf50182ef89966dd2c2bb3796d7bb1487f277c5749472478f) - CALL | MockToken | mint(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
5. [0x5e8c034540fab558251fafe6c19f169aefb257fdac8d0d442732a59ef37ed75f](https://sepolia.uniscan.xyz/tx/0x5e8c034540fab558251fafe6c19f169aefb257fdac8d0d442732a59ef37ed75f) - CALL | MockToken | approve(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
6. [0x3f166abb8af93d072f255bfb589694af8ed53c10af92a46be1c56b95fccac65d](https://sepolia.uniscan.xyz/tx/0x3f166abb8af93d072f255bfb589694af8ed53c10af92a46be1c56b95fccac65d) - CALL | MockToken | approve(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
7. [0x468f152d9e607628319b8cb6e915c07bfd17c3515d5a93943716c36ee75bc893](https://sepolia.uniscan.xyz/tx/0x468f152d9e607628319b8cb6e915c07bfd17c3515d5a93943716c36ee75bc893) - CALL | MockToken | approve(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
8. [0xf565a8d829c4ab31cc5287167e9d5314c09a8ecba4ace2e7e00d73f446b77a08](https://sepolia.uniscan.xyz/tx/0xf565a8d829c4ab31cc5287167e9d5314c09a8ecba4ace2e7e00d73f446b77a08) - CALL | MockToken | approve(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
9. [0xda8a2e6c15fcffa092d235d1b48b09b9695e41051ece27291a320f759c532327](https://sepolia.uniscan.xyz/tx/0xda8a2e6c15fcffa092d235d1b48b09b9695e41051ece27291a320f759c532327) - CALL | - | approve(address,address,uint160,uint48) | 0x000000000022d473030f116ddee9f6b43ac78ba3
10. [0x82eda81699ab7253691c5d588a640f018aec40137cd0eb120c96a99cc1dca11d](https://sepolia.uniscan.xyz/tx/0x82eda81699ab7253691c5d588a640f018aec40137cd0eb120c96a99cc1dca11d) - CALL | - | approve(address,address,uint160,uint48) | 0x000000000022d473030f116ddee9f6b43ac78ba3
11. [0x9107ec5402da0b0fd3148650d02d67d5f7d822200de8309aa9b043d7c6dfbf34](https://sepolia.uniscan.xyz/tx/0x9107ec5402da0b0fd3148650d02d67d5f7d822200de8309aa9b043d7c6dfbf34) - CALL | - | approve(address,address,uint160,uint48) | 0x000000000022d473030f116ddee9f6b43ac78ba3
12. [0x548333823a983be838244158ca79eaa53a05cd7cc407bab86a253cac0b0b96d7](https://sepolia.uniscan.xyz/tx/0x548333823a983be838244158ca79eaa53a05cd7cc407bab86a253cac0b0b96d7) - CALL | - | approve(address,address,uint160,uint48) | 0x000000000022d473030f116ddee9f6b43ac78ba3
13. [0x2929e653647378978ecb12e9fba32cbfd61237752cb8f017b0a07e126b0732b7](https://sepolia.uniscan.xyz/tx/0x2929e653647378978ecb12e9fba32cbfd61237752cb8f017b0a07e126b0732b7) - CREATE | LiquidityVault | - | 0xe9c26cdbb509e1515d06d8eaca74c63e08143977
14. [0x593215dea4e55d00de5bc35ce3da7f734c88651a0b403ff7615e399a20dfa4d5](https://sepolia.uniscan.xyz/tx/0x593215dea4e55d00de5bc35ce3da7f734c88651a0b403ff7615e399a20dfa4d5) - CREATE2 | FractionalLPHook | - | 0xbc395b61ccd210eaa3c0f69d1a2f6bfa7598c0c0
15. [0xc3132bf7d4c6c505fc7dd47e4a1311aed96a2ee7f18fd268b9ac3a478e576a24](https://sepolia.uniscan.xyz/tx/0xc3132bf7d4c6c505fc7dd47e4a1311aed96a2ee7f18fd268b9ac3a478e576a24) - CALL | LiquidityVault | setHook(address) | 0xe9c26cdbb509e1515d06d8eaca74c63e08143977
16. [0xfd526d6bd41346cb5eeecd6b8bb722cd0497a0f9b5ad12aaf7dc6bc324d5c909](https://sepolia.uniscan.xyz/tx/0xfd526d6bd41346cb5eeecd6b8bb722cd0497a0f9b5ad12aaf7dc6bc324d5c909) - CALL | - | initialize((address,address,uint24,int24,address),uint160) | 0x00b036b58a818b1bc34d502d3fe730db729e62ac
17. [0x831cf30733074e34b0f970860d931ed6ec741e8d2b331f712e4cfb5bbd44f254](https://sepolia.uniscan.xyz/tx/0x831cf30733074e34b0f970860d931ed6ec741e8d2b331f712e4cfb5bbd44f254) - CALL | FractionalLPHook | registerPool((address,address,uint24,int24,address)) | 0xbc395b61ccd210eaa3c0f69d1a2f6bfa7598c0c0
18. [0x2be67fe86b358f9dab965663d07f86ef879edc860b62b18afb7777b249f8bd21](https://sepolia.uniscan.xyz/tx/0x2be67fe86b358f9dab965663d07f86ef879edc860b62b18afb7777b249f8bd21) - CALL | - | modifyLiquidities(bytes,uint256) | 0xf969aee60879c54baaed9f3ed26147db216fd664

### Phase B: User Journey + Lifecycle (26 tx)

1. [0xcc10349a91cb2ca5e06c7063fa25408a4ec5b54b9564fbe92cc559a51aed455e](https://sepolia.uniscan.xyz/tx/0xcc10349a91cb2ca5e06c7063fa25408a4ec5b54b9564fbe92cc559a51aed455e) - CALL | - | - | 0x3e63905833eb3448e873801cc9a1c6212bd4ff01
2. [0x5103ee74365a8b27932820bac6efbcf264b4a7a03b85e37244bd4f120528030f](https://sepolia.uniscan.xyz/tx/0x5103ee74365a8b27932820bac6efbcf264b4a7a03b85e37244bd4f120528030f) - CALL | - | - | 0xd98ecd012cfb0491b13665dcd68fb2c63c243bc4
3. [0xb9aa5cb2815b45b1b7fe0c5912b9951743c47845ef80b561b2074a0756805c16](https://sepolia.uniscan.xyz/tx/0xb9aa5cb2815b45b1b7fe0c5912b9951743c47845ef80b561b2074a0756805c16) - CALL | - | mint(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
4. [0x6071655761e15888a3e1c06acfaea13f28b8101170e7f9cbaef0a0df93989603](https://sepolia.uniscan.xyz/tx/0x6071655761e15888a3e1c06acfaea13f28b8101170e7f9cbaef0a0df93989603) - CALL | - | mint(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
5. [0x9f9c3cc5880f4e67dcebcd6e80692bd4207945d813cf935ab2f4daee6f539b76](https://sepolia.uniscan.xyz/tx/0x9f9c3cc5880f4e67dcebcd6e80692bd4207945d813cf935ab2f4daee6f539b76) - CALL | - | approve(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
6. [0x0c722c7f82eefa004b5c8564439fb1f423751ace6f94e8127f37969868c13bb4](https://sepolia.uniscan.xyz/tx/0x0c722c7f82eefa004b5c8564439fb1f423751ace6f94e8127f37969868c13bb4) - CALL | - | approve(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
7. [0x83fe4c785a09676720decf30afde29d131ea5f68f25e410d3c858e5eef2b4d9e](https://sepolia.uniscan.xyz/tx/0x83fe4c785a09676720decf30afde29d131ea5f68f25e410d3c858e5eef2b4d9e) - CALL | - | deposit(uint256,uint256,address) | 0xe9c26cdbb509e1515d06d8eaca74c63e08143977
8. [0xe966532f5f95ae7b47d62dbd9e352589bff13c92424361082a471445bfd00e95](https://sepolia.uniscan.xyz/tx/0xe966532f5f95ae7b47d62dbd9e352589bff13c92424361082a471445bfd00e95) - CALL | - | mint(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
9. [0x152ddf8bdadb13b309e9adfe7b135e65ed2cac00808e4b407ffcb333b45b3c19](https://sepolia.uniscan.xyz/tx/0x152ddf8bdadb13b309e9adfe7b135e65ed2cac00808e4b407ffcb333b45b3c19) - CALL | - | mint(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
10. [0x6d6cd849e8251ea021e542ef354cb1876414bb3c1e142e8fb54ed17105e59696](https://sepolia.uniscan.xyz/tx/0x6d6cd849e8251ea021e542ef354cb1876414bb3c1e142e8fb54ed17105e59696) - CALL | - | approve(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
11. [0xfd1666af78f9755018c2b747d8da8c1965a641569d288578c58a45a0e4a4ce2a](https://sepolia.uniscan.xyz/tx/0xfd1666af78f9755018c2b747d8da8c1965a641569d288578c58a45a0e4a4ce2a) - CALL | - | approve(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
12. [0x20e15a22c8a6ffc0af5f976f041bce8897fc66adb3952ff13d31208f98906abd](https://sepolia.uniscan.xyz/tx/0x20e15a22c8a6ffc0af5f976f041bce8897fc66adb3952ff13d31208f98906abd) - CALL | - | deposit(uint256,uint256,address) | 0xe9c26cdbb509e1515d06d8eaca74c63e08143977
13. [0xf5965f52b4cc28e07dfff9f407e1cdf35e8ab821183776d84b9228418309cf85](https://sepolia.uniscan.xyz/tx/0xf5965f52b4cc28e07dfff9f407e1cdf35e8ab821183776d84b9228418309cf85) - CALL | - | mint(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
14. [0x138f451caff22843d387f2b8fc76e490f917d80aeb9c3f10f5baeb2ff18e13dc](https://sepolia.uniscan.xyz/tx/0x138f451caff22843d387f2b8fc76e490f917d80aeb9c3f10f5baeb2ff18e13dc) - CALL | - | mint(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
15. [0x879033540deae355bea1fbf88705cecedd156b76ef86631e44dfc83c900dd245](https://sepolia.uniscan.xyz/tx/0x879033540deae355bea1fbf88705cecedd156b76ef86631e44dfc83c900dd245) - CALL | - | mint(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
16. [0x62e517ce4f08a53dfc83ec94f47e65bf3260fbb76ede7adc44411626abf2fe99](https://sepolia.uniscan.xyz/tx/0x62e517ce4f08a53dfc83ec94f47e65bf3260fbb76ede7adc44411626abf2fe99) - CALL | - | mint(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
17. [0xf6fa2123957c708fad2c53b820ce1d0547b2077f1d5b8bb2d2267ceecf82a865](https://sepolia.uniscan.xyz/tx/0xf6fa2123957c708fad2c53b820ce1d0547b2077f1d5b8bb2d2267ceecf82a865) - CALL | - | approve(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
18. [0x40633fb8f2d990fcd3c7a8092e660d86cdbf2044bc981fb179138aa4f0bf40b9](https://sepolia.uniscan.xyz/tx/0x40633fb8f2d990fcd3c7a8092e660d86cdbf2044bc981fb179138aa4f0bf40b9) - CALL | - | approve(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
19. [0x57b8a503173dff66873aa41f46584986f617e3d81ceea6e23c9b109c0ce7a6e4](https://sepolia.uniscan.xyz/tx/0x57b8a503173dff66873aa41f46584986f617e3d81ceea6e23c9b109c0ce7a6e4) - CALL | - | approve(address,uint256) | 0x369b5a33e388a631f056e6a398927008ca4c5660
20. [0xd36054aeddec48039cad25f5a96eaae0e944276f148b583d51f5fc789589817c](https://sepolia.uniscan.xyz/tx/0xd36054aeddec48039cad25f5a96eaae0e944276f148b583d51f5fc789589817c) - CALL | - | approve(address,uint256) | 0x46ca7a592990a8d7396dc7d1d761c47c5370993e
21. [0x540c7fe315bca57666f038151645b4b9c428312b665e2acb6d13de42294c0394](https://sepolia.uniscan.xyz/tx/0x540c7fe315bca57666f038151645b4b9c428312b665e2acb6d13de42294c0394) - CALL | - | approve(address,address,uint160,uint48) | 0x000000000022d473030f116ddee9f6b43ac78ba3
22. [0xfb6cd479e2f3240370c0d1f12a868db0af5e1fad0dbfedfd6ee72acad008e03b](https://sepolia.uniscan.xyz/tx/0xfb6cd479e2f3240370c0d1f12a868db0af5e1fad0dbfedfd6ee72acad008e03b) - CALL | - | approve(address,address,uint160,uint48) | 0x000000000022d473030f116ddee9f6b43ac78ba3
23. [0x2a64c168b7fcbff277992db4613acdf5dd9458e0ebcf2ae5599c7acb20df8c28](https://sepolia.uniscan.xyz/tx/0x2a64c168b7fcbff277992db4613acdf5dd9458e0ebcf2ae5599c7acb20df8c28) - CALL | - | approve(address,address,uint160,uint48) | 0x000000000022d473030f116ddee9f6b43ac78ba3
24. [0xfbae1ce14ba532fbc8f7a60d788a6488919dc6a8bbbe5ff49fd130dcd7a3fd8b](https://sepolia.uniscan.xyz/tx/0xfbae1ce14ba532fbc8f7a60d788a6488919dc6a8bbbe5ff49fd130dcd7a3fd8b) - CALL | - | approve(address,address,uint160,uint48) | 0x000000000022d473030f116ddee9f6b43ac78ba3
25. [0xd071bf2dfa311035c015c5b7113e73fafb52ff0546361cbc03ce7816289b6928](https://sepolia.uniscan.xyz/tx/0xd071bf2dfa311035c015c5b7113e73fafb52ff0546361cbc03ce7816289b6928) - CALL | - | swapExactTokensForTokens(uint256,uint256,bool,(address,address,uint24,int24,address),bytes,address,uint256) | 0x9cd2b0a732dd5e023a5539921e0fd1c30e198dba
26. [0xd97f4df7cfcb9883a0607d58f304a6c09978646709059ffbff9e81691024e7bb](https://sepolia.uniscan.xyz/tx/0xd97f4df7cfcb9883a0607d58f304a6c09978646709059ffbff9e81691024e7bb) - CALL | - | redeem(uint256,address) | 0xe9c26cdbb509e1515d06d8eaca74c63e08143977

## Local Demo Flow

```bash
anvil
make demo-local
```

Lifecycle executed by script:

1. deploys Uniswap v4 artifacts + mock tokens
2. deploys hook and vault
3. creates pool and seeds liquidity
4. user A deposits, user B deposits
5. swap executes and fee signal accrues
6. user A redeems
7. prints deterministic summary values

## Targets

- `make demo-local`
- `make demo-testnet`
- `make demo-fractional`
