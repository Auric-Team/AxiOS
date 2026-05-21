"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.seedAdminUser = seedAdminUser;
const User_1 = __importDefault(require("../models/User"));
const crypto_1 = require("../utils/crypto");
const Log_1 = require("../models/Log");
/**
 * Seeds a default administrator account if the user collection is empty.
 */
async function seedAdminUser() {
    try {
        const adminCount = await User_1.default.countDocuments({ role: 'admin' });
        if (adminCount === 0) {
            const defaultAdmin = new User_1.default({
                username: 'admin',
                passwordHash: (0, crypto_1.hashPassword)('admin123'),
                role: 'admin'
            });
            await defaultAdmin.save();
            await (0, Log_1.dbLog)('info', 'system', 'Database initialized. Created default administrator: admin / admin123');
        }
    }
    catch (error) {
        console.error('[Seed Error] Failed to seed default admin:', error);
    }
}
