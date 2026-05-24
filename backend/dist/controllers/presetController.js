"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPresets = getPresets;
exports.createPreset = createPreset;
exports.deletePreset = deletePreset;
const Preset_1 = __importDefault(require("../models/Preset"));
const Log_1 = require("../models/Log");
/**
 * Fetch all available game presets.
 */
async function getPresets(req, res) {
    try {
        const presets = await Preset_1.default.find().sort({ name: 1 });
        res.json({ success: true, presets });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to fetch game presets.' });
    }
}
/**
 * Admin-only: Create a new game preset.
 */
async function createPreset(req, res) {
    const ip = req.ip || req.socket.remoteAddress;
    try {
        const { package: pkg, name } = req.body;
        if (!pkg || !name) {
            return res.status(400).json({ error: 'Package ID and Game Name are required.' });
        }
        const cleanPkg = pkg.trim();
        const cleanName = name.trim();
        const exists = await Preset_1.default.findOne({ package: cleanPkg });
        if (exists) {
            return res.status(400).json({ error: `Preset already exists for package ID: ${cleanPkg}` });
        }
        const newPreset = new Preset_1.default({
            package: cleanPkg,
            name: cleanName
        });
        await newPreset.save();
        await (0, Log_1.dbLog)('info', 'system', `Admin ${req.user?.username} added target preset: ${cleanName} (${cleanPkg})`, ip);
        res.json({ success: true, preset: newPreset });
    }
    catch (e) {
        console.error('[Preset] Creation Error:', e);
        res.status(500).json({ error: 'Failed to create game preset.' });
    }
}
/**
 * Admin-only: Delete a game preset.
 */
async function deletePreset(req, res) {
    const ip = req.ip || req.socket.remoteAddress;
    try {
        const { packageId } = req.params;
        const deleted = await Preset_1.default.findOneAndDelete({ package: packageId });
        if (!deleted) {
            return res.status(404).json({ error: 'Preset not found.' });
        }
        await (0, Log_1.dbLog)('info', 'system', `Admin ${req.user?.username} deleted target preset: ${deleted.name} (${deleted.package})`, ip);
        res.json({ success: true, message: 'Game preset deleted successfully.' });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to delete game preset.' });
    }
}
