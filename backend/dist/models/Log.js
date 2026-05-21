"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.Log = void 0;
exports.dbLog = dbLog;
const mongoose_1 = __importStar(require("mongoose"));
const logSchema = new mongoose_1.Schema({
    level: { type: String, enum: ['info', 'warn', 'error'], required: true, index: true },
    message: { type: String, required: true },
    category: { type: String, enum: ['auth', 'key', 'download', 'upload', 'system'], required: true, index: true },
    ip: { type: String },
    deviceInfo: { type: String },
    timestamp: { type: Date, default: Date.now, index: true }
});
exports.Log = mongoose_1.default.model('Log', logSchema);
/**
 * Helper to log an event directly to the database.
 */
async function dbLog(level, category, message, ip, deviceInfo) {
    try {
        await exports.Log.create({ level, category, message, ip, deviceInfo });
        console.log(`[DB Log] [${level.toUpperCase()}] [${category}] ${message}`);
    }
    catch (err) {
        console.error(`Failed to write log to DB:`, err);
    }
}
exports.default = exports.Log;
