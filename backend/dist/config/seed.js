"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.seedAdminUser = seedAdminUser;
const User_1 = __importDefault(require("../models/User"));
const Preset_1 = __importDefault(require("../models/Preset"));
const crypto_1 = require("../utils/crypto");
const Log_1 = require("../models/Log");
/**
 * Seeds default administrator credentials and game presets if the collections are empty.
 */
async function seedAdminUser() {
    try {
        // 1. Seed Default Administrator
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
        // 2. Seed Default Target Preset
        const presetCount = await Preset_1.default.countDocuments();
        if (presetCount === 0) {
            const defaultPreset = new Preset_1.default({
                name: 'Last Island of Survival',
                package: 'com.herogame.gplay.lastdayrulessurvival'
            });
            await defaultPreset.save();
            await (0, Log_1.dbLog)('info', 'system', 'Database initialized. Created default target preset: Last Island of Survival (com.herogame.gplay.lastdayrulessurvival)');
        }
    }
    catch (error) {
        console.error('[Seed Error] Failed to seed default system properties:', error);
    }
}
