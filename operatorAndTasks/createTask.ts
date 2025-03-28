import {anvil} from "viem/chains"
import 'dotenv/config'
import { parseAbi, http, createPublicClient, createWalletClient } from "viem";
import { privateKeyToAccount } from "viem/accounts";

if(!process.env.PRIVATE_KEY){

    throw new Error('Please set your PRIVATE_KEY')

}

type Task = {
    contents: string,
    taskCreatedBlock: number
};

const abi = parseAbi([
    'function createNewTask(string memory contents) external returns ((string contents, uint32 taskCreatedBlock))',
    ])

async function main(){
    const contractAddress = "0xe3e4631D734e4b3F900AfcC396440641Ed0df339"

    const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`);
    console.log("account:",account)

    const publicClient = createPublicClient({
        chain: anvil,
        transport:http('http://localhost:8545'),
    })

    const walletClient = createWalletClient({
        chain: anvil,
        transport:http('http://localhost:8545'),
        account,
    })

    try{
        const {request} = await publicClient.simulateContract({
            address: contractAddress,
            abi,
            functionName: 'createNewTask',
            args: ['hello world'],
            account: account.address
        })

        const hash = await walletClient.writeContract(request)
        const receipt = await publicClient.waitForTransactionReceipt({hash})
        console.log("transaction hash:",hash)
        console.log("transaction receipt:",receipt)
    }
    catch(e){
        console.log("error:",e)
    }


}

main().catch(console.error)