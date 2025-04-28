const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CampusCoin", function () {
  let campusCoin;
  let admin, university, student, provider;

  before(async () => {
    [admin, university, student, provider] = await ethers.getSigners();
    const CampusCoin = await ethers.getContractFactory("CampusCoin");
    campusCoin = await CampusCoin.deploy(university.address);
  });

  describe("Deployment", () => {
    it("Should set university and admin correctly", async () => {
    
    });
  });

  
});
