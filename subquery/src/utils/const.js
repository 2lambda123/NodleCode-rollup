"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
    return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.abi = exports.nodleContracts = exports.SEPOLIA_RPC_URL = void 0;
exports.callContract = callContract;
var ethers_1 = require("ethers");
var node_fetch_1 = require("node-fetch");
exports.SEPOLIA_RPC_URL = "https://mainnet.era.zksync.io";
function callContract(contractAddress_1, abi_1, methodName_1) {
    return __awaiter(this, arguments, void 0, function (contractAddress, abi, methodName, params) {
        var iface, data, payload, response, responseData, decodedResult, error_1;
        if (params === void 0) { params = []; }
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    iface = new ethers_1.ethers.utils.Interface(abi);
                    data = iface.encodeFunctionData(methodName, params);
                    payload = {
                        jsonrpc: "2.0",
                        method: "eth_call",
                        params: [
                            {
                                to: contractAddress,
                                data: data,
                            },
                            "latest",
                        ],
                        id: 1,
                    };
                    _a.label = 1;
                case 1:
                    _a.trys.push([1, 4, , 5]);
                    return [4 /*yield*/, (0, node_fetch_1.default)(exports.SEPOLIA_RPC_URL, {
                            method: "POST",
                            headers: {
                                "Content-Type": "application/json",
                            },
                            body: JSON.stringify(payload),
                        })];
                case 2:
                    response = _a.sent();
                    return [4 /*yield*/, response.json()];
                case 3:
                    responseData = _a.sent();
                    if (responseData.result) {
                        decodedResult = iface.decodeFunctionResult(methodName, responseData.result);
                        return [2 /*return*/, decodedResult];
                    }
                    else {
                        throw new Error("RPC Error: ".concat(responseData.error.message));
                    }
                    return [3 /*break*/, 5];
                case 4:
                    error_1 = _a.sent();
                    throw new Error("Fetch Error: ".concat(error_1.message));
                case 5: return [2 /*return*/];
            }
        });
    });
}
exports.nodleContracts = [
    "0x95b3641d549f719eb5105f9550eca4a7a2f305de",
    "0xd837cFb550b7402665499f136eeE7a37D608Eb18",
    "0x9Fed2d216DBE36928613812400Fd1B812f118438",
    "0x999368030Ba79898E83EaAE0E49E89B7f6410940",
];
exports.abi = [
    // Minimal ERC721 ABI with only the tokenURI method
    "function tokenURI(uint256 tokenId) view returns (string)",
    "function symbol() view returns (string)",
    "function name() view returns (string)",
    "function supportsInterface(bytes4 interfaceId) view returns (bool)",
];
