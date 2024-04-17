import { Clarinet, Tx, Chain, Account, types } from "https://deno.land/x/clarinet@v0.34.0/index.ts";
import { YieldVault } from "./models/ainomo-tests-auto.ts";
import { ReservePool } from "./models/ainomo-tests-reserve-pool.ts";
import { FungibleToken } from "./models/ainomo-tests-tokens.ts";

const ONE_8 = 100000000

const ACTIVATION_BLOCK = 20;
const BountyFixed = 0.1e8;

Clarinet.test({
    name: "auto-ainomo : ensure that privileged setters can only be called by contract owner",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        var notContractOwner = accounts.get("wallet_1")!;
        var wallet_2 = accounts.get("wallet_2")!;

        let block = chain.mineBlock([
            Tx.contractCall(
                "auto-ainomo",
                "set-contract-owner",
                [types.principal(wallet_2.address)],
                notContractOwner.address
            ),
            Tx.contractCall(
                "auto-ainomo",
                "set-start-block",
                [types.uint(0)],
                notContractOwner.address
            ),      
            Tx.contractCall(
                "auto-ainomo",
                "set-bounty-in-fixed",
                [types.uint(0)],
                notContractOwner.address
            ),                                              
        ]);
        for(let i = 0; i < block.receipts.length; i++){
            block.receipts[i].result.expectErr().expectUint(1000);
        }
    },
});

Clarinet.test({
    name: "auto-ainomo : ensure that contract is activated when adding to position",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet_1 = accounts.get("wallet_1")!;
        const yieldVault = new YieldVault(chain, "auto-ainomo");
        const reservePool = new ReservePool(chain);
        const ainomoToken = new FungibleToken(chain, deployer, "age000-governance-token");
        const dx = 50000 * ONE_8;

        let result:any = ainomoToken.mintFixed(deployer, wallet_1.address, dx);
        result.expectOk();

        const setupBlock = chain.mineBlock([
            reservePool.addToken(deployer, ainomoTokenAddress),
            reservePool.setActivationBlock(deployer, ainomoTokenAddress, ACTIVATION_BLOCK),
            reservePool.setCoinbaseAmount(deployer, ainomoTokenAddress, ONE_8, ONE_8, ONE_8, ONE_8, ONE_8)            
        ]);
        for(let i = 0; i < setupBlock.receipts.length; i++){
            setupBlock.receipts[i].result.expectOk();
        }

        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK);

        const addBlock = chain.mineBlock([
            yieldVault.addToPosition(wallet_1, dx)
        ]);
        addBlock.receipts[0].result.expectErr().expectUint(2043);; //ERR-NOT-ACTIVATED
    }
})

Clarinet.test({
    name: "auto-ainomo : ensure that stacking is available when adding to position",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet_1 = accounts.get("wallet_1")!;
        const yieldVault = new YieldVault(chain, "auto-ainomo");
        const reservePool = new ReservePool(chain);
        const ainomoToken = new FungibleToken(chain, deployer, "age000-governance-token");
        const dx = 50000 * ONE_8;

        let result:any = ainomoToken.mintFixed(deployer, wallet_1.address, dx);
        result.expectOk();

        const setupBlock = chain.mineBlock([
            reservePool.addToken(deployer, ainomoTokenAddress),
            reservePool.setActivationBlock(deployer, ainomoTokenAddress, ACTIVATION_BLOCK),
            reservePool.setCoinbaseAmount(deployer, ainomoTokenAddress, ONE_8, ONE_8, ONE_8, ONE_8, ONE_8),
            yieldVault.setStartBlock(deployer, 0)   
        ]);
        for(let i = 0; i < setupBlock.receipts.length; i++){
            setupBlock.receipts[i].result.expectOk();
        }

        const addBlock = chain.mineBlock([
            yieldVault.addToPosition(wallet_1, dx)
        ]);
        addBlock.receipts[0].result.expectErr().expectUint(10015);; //ERR-STACKING-NOT-AVAILABLE
    }
})

Clarinet.test({
    name: "auto-ainomo : ensure that add-to-position works on a valid pool",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet_1 = accounts.get("wallet_1")!;
        const wallet_2 = accounts.get("wallet_2")!;
        const yieldVault = new YieldVault(chain, "auto-ainomo");
        const reservePool = new ReservePool(chain);
        const ainomoToken = new FungibleToken(chain, deployer, "age000-governance-token");
        const dx = ONE_8;

        let result:any = ainomoToken.mintFixed(deployer, wallet_1.address, dx);
        result.expectOk();

        let block = chain.mineBlock([
            reservePool.addToken(deployer, ainomoTokenAddress),
            reservePool.setActivationBlock(deployer, ainomoTokenAddress, ACTIVATION_BLOCK),
            reservePool.setCoinbaseAmount(deployer, ainomoTokenAddress, ONE_8, ONE_8, ONE_8, ONE_8, ONE_8),
            yieldVault.setStartBlock(deployer, 0)      
        ]);
        for(let i = 0; i < block.receipts.length; i++){
            block.receipts[i].result.expectOk();
        }

        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK);

        block = chain.mineBlock([
            yieldVault.addToPosition(wallet_1, dx)
        ]);
        block.receipts[0].result.expectOk().expectBool(true);
        // console.log(block.receipts[0].events);

        block.receipts[0].events.expectFungibleTokenTransferEvent(
            dx,
            wallet_1.address,
            deployer.address + ".auto-ainomo",
            "ainomo"
        );
        block.receipts[0].events.expectFungibleTokenTransferEvent(
            dx,
            deployer.address + ".auto-ainomo",
            deployer.address + ".ainomo-vault",
            "ainomo"
        );
        block.receipts[0].events.expectFungibleTokenMintEvent(
            dx,
            wallet_1.address,
            "auto-ainomo"
        );
        
        // end of cycle 0
        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + 525);

        result = ainomoToken.mintFixed(deployer, wallet_2.address, dx);
        result.expectOk();        

        block = chain.mineBlock([
            yieldVault.addToPosition(wallet_2, dx)
        ]);
        block.receipts[0].result.expectOk().expectBool(true);
        // console.log(block.receipts[0].events);

        block.receipts[0].events.expectFungibleTokenTransferEvent(
            dx,
            wallet_2.address,
            deployer.address + ".auto-ainomo",
            "ainomo"
        );
        block.receipts[0].events.expectFungibleTokenTransferEvent(
            dx,
            deployer.address + ".auto-ainomo",
            deployer.address + ".ainomo-vault",
            "ainomo"
        );
        block.receipts[0].events.expectFungibleTokenMintEvent(
            dx / 2,
            wallet_2.address,
            "auto-ainomo"
        );
    }
})

Clarinet.test({
    name: "auto-ainomo : ensure that claim-and-stake cannot claim future cycles",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet_1 = accounts.get("wallet_1")!;
        const wallet_2 = accounts.get("wallet_2")!;
        const yieldVault = new YieldVault(chain, "auto-ainomo");
        const reservePool = new ReservePool(chain);
        const ainomoToken = new FungibleToken(chain, deployer, "age000-governance-token");
        const dx = ONE_8;

        let result:any = ainomoToken.mintFixed(deployer, wallet_1.address, dx);
        result.expectOk();

        let block = chain.mineBlock([
            reservePool.addToken(deployer, ainomoTokenAddress),
            reservePool.setActivationBlock(deployer, ainomoTokenAddress, ACTIVATION_BLOCK),
            reservePool.setCoinbaseAmount(deployer, ainomoTokenAddress, ONE_8, ONE_8, ONE_8, ONE_8, ONE_8),
            yieldVault.setStartBlock(deployer, 0)      
        ]);
        for(let i = 0; i < block.receipts.length; i++){
            block.receipts[i].result.expectOk();
        }

        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK);

        block = chain.mineBlock([
            yieldVault.addToPosition(wallet_1, dx)
        ]);
        block.receipts[0].result.expectOk().expectBool(true);
        // console.log(block.receipts[0].events);

        block.receipts[0].events.expectFungibleTokenTransferEvent(
            dx,
            wallet_1.address,
            deployer.address + ".auto-ainomo",
            "ainomo"
        );
        block.receipts[0].events.expectFungibleTokenTransferEvent(
            dx,
            deployer.address + ".auto-ainomo",
            deployer.address + ".ainomo-vault",
            "ainomo"
        );
        block.receipts[0].events.expectFungibleTokenMintEvent(
            dx,
            wallet_1.address,
            "auto-ainomo"
        );
        
        // end of cycle 0
        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + 525);

        block = chain.mineBlock([
            yieldVault.claimAndStake(wallet_2, 2)
        ]);
        block.receipts[0].result.expectErr().expectUint(10017); //ERR-REWARD-CYCLE-NOT-COMPLETED
    }
})

Clarinet.test({
    name: "auto-ainomo : ensure that claim-and-stake works with a valid cycle",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet_1 = accounts.get("wallet_1")!;
        const wallet_2 = accounts.get("wallet_2")!;
        const yieldVault = new YieldVault(chain, "auto-ainomo");
        const reservePool = new ReservePool(chain);
        const ainomoToken = new FungibleToken(chain, deployer, "age000-governance-token");
        const dx = ONE_8;

        let result:any = ainomoToken.mintFixed(deployer, wallet_1.address, dx);
        result.expectOk();

        let block = chain.mineBlock([
            reservePool.addToken(deployer, ainomoTokenAddress),
            reservePool.setActivationBlock(deployer, ainomoTokenAddress, ACTIVATION_BLOCK),
            reservePool.setCoinbaseAmount(deployer, ainomoTokenAddress, ONE_8, ONE_8, ONE_8, ONE_8, ONE_8),
            yieldVault.setStartBlock(deployer, 0)   ,
            yieldVault.setBountyInFixed(deployer, BountyFixed)   
        ]);
        block.receipts.forEach(e => { e.result.expectOk() });

        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK);

        block = chain.mineBlock([
            yieldVault.addToPosition(wallet_1, dx)
        ]);
        block.receipts.forEach(e => { e.result.expectOk() });

        block.receipts[0].events.expectFungibleTokenTransferEvent(
            dx,
            wallet_1.address,
            deployer.address + ".auto-ainomo",
            "ainomo"
        );
        block.receipts[0].events.expectFungibleTokenTransferEvent(
            dx,
            deployer.address + ".auto-ainomo",
            deployer.address + ".ainomo-vault",
            "ainomo"
        );
        block.receipts[0].events.expectFungibleTokenMintEvent(
            dx,
            wallet_1.address,
            "auto-ainomo"
        );
        
        // end of cycle 1
        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + 1050);

        block = chain.mineBlock([
            yieldVault.setBountyInFixed(deployer, ONE_8),
        ]);
        block.receipts.forEach(e => { e.result.expectOk() });

        block = chain.mineBlock([
            yieldVault.setBountyInFixed(wallet_2, BountyFixed),
            yieldVault.claimAndStake(wallet_2, 1)
        ]);
        block.receipts.forEach(e => { e.result.expectErr() });

        block = chain.mineBlock([
            yieldVault.setBountyInFixed(deployer, BountyFixed),
            yieldVault.claimAndStake(wallet_2, 1)
        ]);
        block.receipts.forEach(e => { e.result.expectOk() });

        block.receipts[1].events.expectFungibleTokenMintEvent(
            ONE_8,
            deployer.address + ".auto-ainomo",
            "ainomo"
        );        
        block.receipts[1].events.expectFungibleTokenTransferEvent(
            BountyFixed,
            deployer.address + ".auto-ainomo",
            wallet_2.address,
            "ainomo"
        );
        block.receipts[1].events.expectFungibleTokenTransferEvent(
            ONE_8 - BountyFixed,
            deployer.address + ".auto-ainomo",
            deployer.address + ".ainomo-vault",
            "ainomo"
        );

    }
})

Clarinet.test({
    name: "auto-ainomo : ensure that claim-and-mint works with valid cycles",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet_1 = accounts.get("wallet_1")!;
        const wallet_2 = accounts.get("wallet_2")!;
        const yieldVault = new YieldVault(chain, "auto-ainomo");
        const reservePool = new ReservePool(chain);
        const ainomoToken = new FungibleToken(chain, deployer, "age000-governance-token");
        const dx = ONE_8;

        let result:any = ainomoToken.mintFixed(deployer, wallet_1.address, dx);
        result.expectOk();

        let block = chain.mineBlock([
            reservePool.addToken(deployer, ainomoTokenAddress),
            reservePool.setActivationBlock(deployer, ainomoTokenAddress, ACTIVATION_BLOCK),
            reservePool.setCoinbaseAmount(deployer, ainomoTokenAddress, ONE_8, ONE_8, ONE_8, ONE_8, ONE_8),
            yieldVault.setStartBlock(deployer, 0)   ,
            yieldVault.setBountyInFixed(deployer, BountyFixed)   
        ]);
        block.receipts.forEach(e => { e.result.expectOk() });

        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK);


        block = chain.mineBlock([
            Tx.contractCall("ainomo-reserve-pool", "stake-tokens", 
                [
                    types.principal(ainomoTokenAddress), 
                    types.uint(dx),
                    types.uint(32)
                ],
                wallet_1.address
            )
        ]);
        block.receipts.forEach(e => { e.result.expectOk() });
        
        // end of cycle 3
        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + 2100);

        block = chain.mineBlock([
            Tx.contractCall("auto-ainomo", "claim-and-mint", [types.list([types.uint(0)])], wallet_1.address),
            Tx.contractCall("auto-ainomo", "claim-and-mint", [types.list([types.uint(1), types.uint(2), types.uint(3)])], wallet_1.address)
        ]);
        // console.log(block.receipts[1].events);
        block.receipts[0].result.expectErr().expectUint(2003);
        block.receipts[1].result.expectOk();

        block.receipts[1].events.expectFungibleTokenMintEvent(
            3 * ONE_8,
            wallet_1.address,
            "auto-ainomo"
        );        
        block.receipts[1].events.expectFungibleTokenMintEvent(
            3 * ONE_8,
            wallet_1.address,
            "ainomo"
        );
        block.receipts[1].events.expectFungibleTokenTransferEvent(
            3 * ONE_8,
            wallet_1.address,
            deployer.address + '.auto-ainomo',
            "ainomo"
        );      
        block.receipts[1].events.expectFungibleTokenTransferEvent(
            3 * ONE_8,
            deployer.address + '.auto-ainomo',
            deployer.address + '.ainomo-vault',
            "ainomo"
        );          
    }
})

Clarinet.test({
    name: "auto-ainomo : ensure that reduce-position works",
    async fn(chain: Chain, accounts: Map<string, Account>) {
      const deployer = accounts.get("deployer")!;
      const wallet_1 = accounts.get("wallet_1")!;
      const wallet_2 = accounts.get("wallet_2")!;
      const yieldVault = new YieldVault(chain, "auto-ainomo");
      const reservePool = new ReservePool(chain);
      const ainomoToken = new FungibleToken(
        chain,
        deployer,
        "age000-governance-token"
      );
      const dx = ONE_8;
      const end_cycle = 120;
  
      let result: any = ainomoToken.mintFixed(deployer, wallet_1.address, dx);
      result.expectOk();
  
      let block = chain.mineBlock([
        Tx.contractCall(
          "ainomo-vault",
          "add-approved-token",
          [types.principal(ainomoTokenAddress)],
          deployer.address
        ),
        reservePool.addToken(deployer, ainomoTokenAddress),
        reservePool.setActivationBlock(
          deployer,
          ainomoTokenAddress,
          ACTIVATION_BLOCK
        ),
        reservePool.setCoinbaseAmount(
          deployer,
          ainomoTokenAddress,
          ONE_8,
          ONE_8,
          ONE_8,
          ONE_8,
          ONE_8
        ),
        yieldVault.setStartBlock(deployer, 0)   ,
        yieldVault.setBountyInFixed(deployer, 0),
      ]);
      block.receipts.forEach((e) => { e.result.expectOk() });
  
      block = chain.mineBlock([
        yieldVault.setEndCycle(wallet_1, end_cycle),
        yieldVault.setEndCycle(deployer, end_cycle)
      ]);
      block.receipts[0].result.expectErr().expectUint(1000);
      block.receipts[1].result.expectOk();
  
      chain.mineEmptyBlockUntil(ACTIVATION_BLOCK);
  
      block = chain.mineBlock([yieldVault.addToPosition(wallet_1, dx)]);
      block.receipts.forEach((e) => { e.result.expectOk() });
  
      for(let cycle = 1; cycle < end_cycle; cycle++){
        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + (cycle + 1) * 525);   
        block = chain.mineBlock([yieldVault.claimAndStake(wallet_2, cycle)]);
        block.receipts.forEach(e => { e.result.expectOk() });
      }
      // end of cycle
      chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + (end_cycle + 1) * 525);
  
      block = chain.mineBlock([yieldVault.reducePosition(wallet_1, ONE_8)]);
      // console.log(block.receipts[0].events);
      block.receipts.forEach(e => { e.result.expectOk() });
  
      block.receipts[0].events.expectFungibleTokenTransferEvent(
        ONE_8 * end_cycle + dx,
        deployer.address + ".auto-ainomo",
        wallet_1.address,
        "ainomo"
      );
      block.receipts[0].events.expectFungibleTokenBurnEvent(
        dx,
        wallet_1.address,
        "auto-ainomo"
      )    
    },
  });

  Clarinet.test({
    name: "auto-ainomo : ensure that x works",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet_1 = accounts.get("wallet_1")!;
        const wallet_2 = accounts.get("wallet_2")!;
        const yieldVault = new YieldVault(chain, "auto-ainomo");
        const reservePool = new ReservePool(chain);
        const ainomoToken = new FungibleToken(chain, deployer, "age000-governance-token");
        const dx = ONE_8;
        const tranche_1_cycle = 10;
        const tranche_2_cycle = 20;

        let result = ainomoToken.mintFixed(deployer, deployer.address, 2 * dx);
        result.expectOk(); 

        let block = chain.mineBlock([

            reservePool.addToken(deployer, ainomoTokenAddress),
            reservePool.setActivationBlock(deployer, ainomoTokenAddress, ACTIVATION_BLOCK),
            reservePool.setCoinbaseAmount(deployer, ainomoTokenAddress, ONE_8, ONE_8, ONE_8, ONE_8, ONE_8),
            yieldVault.setStartBlock(deployer, 0),
            yieldVault.setBountyInFixed(deployer, BountyFixed),
        ]);
        block.receipts.forEach(e => { e.result.expectOk() });

        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK);

        block = chain.mineBlock([
            yieldVault.addToPosition(deployer, dx),                                
            Tx.contractCall("simple-weight-pool-ainomo", "create-pool", 
                [
                    types.principal(deployer.address + ".age000-governance-token"),
                    types.principal(deployer.address + ".auto-ainomo"),
                    types.principal(deployer.address + ".fwp-ainomo-autoainomo"),
                    types.principal(deployer.address + ".multisig-fwp-ainomo-autoainomo"),
                    types.uint(dx),
                    types.uint(dx)
                ], deployer.address
            ),
            Tx.contractCall("auto-fwp-ainomo-autoainomo-x-v1-01", "set-start-block", [types.uint(ACTIVATION_BLOCK)], deployer.address),
            Tx.contractCall("auto-fwp-ainomo-autoainomo-x-v1-01", "set-tranche-end-block", [types.uint(1), types.uint(ACTIVATION_BLOCK + (tranche_1_cycle + 1) * 525)], deployer.address),
            Tx.contractCall("auto-fwp-ainomo-autoainomo-x-v1-01", "set-tranche-end-block", [types.uint(2), types.uint(ACTIVATION_BLOCK + (tranche_2_cycle + 1) * 525)], deployer.address),
            Tx.contractCall("auto-fwp-ainomo-autoainomo-x-v1-01", "set-available-ainomo", [types.principal(wallet_1.address), types.uint(1), types.uint(dx)], deployer.address),
            Tx.contractCall("auto-fwp-ainomo-autoainomo-x-v1-01", "set-available-ainomo", [types.principal(wallet_1.address), types.uint(2), types.uint(dx)], deployer.address),                            
            Tx.contractCall("auto-fwp-ainomo-autoainomo-x-v1-01", "add-to-position", [types.uint(1), types.uint(dx)], wallet_1.address),
            Tx.contractCall("auto-fwp-ainomo-autoainomo-x-v1-01", "add-to-position", [types.uint(2), types.uint(dx)], wallet_1.address)
        ]);
        block.receipts.forEach(e => { e.result.expectOk() });

        for(let cycle = 1; cycle < tranche_1_cycle; cycle++){
            chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + (cycle + 1) * 525);   
            block = chain.mineBlock([yieldVault.claimAndStake(wallet_2, cycle)]);
            block.receipts.forEach(e => { e.result.expectOk() });
        }

          // end of tranche 1
        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + (tranche_1_cycle + 1) * 525 + 1);

        block = chain.mineBlock([
            Tx.contractCall("auto-fwp-ainomo-autoainomo-x-v1-01", "reduce-position", [types.uint(1)], wallet_1.address),
            yieldVault.claimAndStake(wallet_2, tranche_1_cycle)
        ]);
        block.receipts.forEach(e => { e.result.expectOk() });

        for(let cycle = tranche_1_cycle + 1; cycle < tranche_2_cycle; cycle++){
            chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + (cycle + 1) * 525);   
            block = chain.mineBlock([yieldVault.claimAndStake(wallet_2, cycle)]);
            block.receipts.forEach(e => { e.result.expectOk() });
        }        

        // end of tranche 2
        chain.mineEmptyBlockUntil(ACTIVATION_BLOCK + (tranche_2_cycle + 1) * 525 + 1);

        block = chain.mineBlock([
            Tx.contractCall("auto-fwp-ainomo-autoainomo-x-v1-01", "reduce-position", [types.uint(2)], wallet_1.address)
        ]);        
        block.receipts.forEach(e => { e.result.expectOk() });        
        // console.log(block.receipts[0].events);
    }
})

