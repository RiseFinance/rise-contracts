import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Place Limit Order", function() {

    async function deployContractsFixture() {
        const [deployer, trader] = await ethers.getSigners();
        const limitOrderBook = await (await ethers.getContractFactory("LimitOrderBook")).deploy();
    }

});
