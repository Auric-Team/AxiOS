"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.hashPassword = hashPassword;
const crypto_1 = __importDefault(require("crypto"));
/**
 * Generates a SHA-256 hash of a string.
 * @param text The input string to hash
 */
function hashPassword(text) {
    return crypto_1.default.createHash('sha256').update(text).digest('hex');
}
