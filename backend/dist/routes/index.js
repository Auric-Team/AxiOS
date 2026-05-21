"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const authRoutes_1 = __importDefault(require("./authRoutes"));
const deployRoutes_1 = __importDefault(require("./deployRoutes"));
const keyRoutes_1 = __importDefault(require("./keyRoutes"));
const logRoutes_1 = __importDefault(require("./logRoutes"));
const router = (0, express_1.Router)();
// Map sub-routes under the API prefix
router.use('/', authRoutes_1.default);
router.use('/', deployRoutes_1.default);
router.use('/keys', keyRoutes_1.default);
router.use('/logs', logRoutes_1.default);
exports.default = router;
