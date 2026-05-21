"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.connectDatabase = connectDatabase;
const mongoose_1 = __importDefault(require("mongoose"));
const config_1 = __importDefault(require("../config"));
/**
 * Connects to MongoDB Atlas cluster using the environment URI.
 */
async function connectDatabase() {
    console.log('[Database] Connecting to MongoDB Atlas...');
    const maxRetries = 5;
    let attempt = 0;
    while (attempt < maxRetries) {
        try {
            await mongoose_1.default.connect(config_1.default.mongoUri);
            console.log('[Database] Successfully connected to MongoDB Database Cluster.');
            return;
        }
        catch (error) {
            attempt++;
            console.error(`[Database] Connection attempt ${attempt}/${maxRetries} failed:`, error);
            if (attempt >= maxRetries) {
                console.error('[Database] Critical: Maximum MongoDB connection retries exceeded.');
                process.exit(1);
            }
            // Wait before retrying (2s, 4s, 6s...)
            const delay = attempt * 2000;
            console.log(`[Database] Waiting ${delay / 1000}s before retrying...`);
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }
}
