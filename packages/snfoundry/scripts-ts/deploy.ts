import { Abi, Contract } from "starknet";
import {
  deployContract,
  executeDeployCalls,
  exportDeployments,
  deployer,
  provider,
} from "./deploy-contract";
import { green } from "./helpers/colorize-log";

import preDeployedContracts from "../../nextjs/contracts/predeployedContracts";

const deployScript = async (): Promise<void> => {
  const { address: diceGameAddr } = await deployContract({
    contract: "DiceGame",
    constructorArgs: {
      eth_token_address:
        "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7",
    },
  });

  // I don't have that much ETH in my wallet, so I'm not going send ETH to the DiceGame contract

  // ToDo Checkpoint 2: Deploy RiggedRoll contract
  await deployContract({
    contract: "RiggedRoll",
    constructorArgs: {
      dice_game_address: diceGameAddr,
      owner: deployer.address,
    },
  });
};

deployScript()
  .then(async () => {
    await executeDeployCalls();
    exportDeployments();

    console.log(green("All Setup Done"));
  })
  .catch(console.error);
