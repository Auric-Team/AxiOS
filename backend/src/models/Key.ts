import mongoose, { Document, Schema } from 'mongoose';

export interface IKey extends Document {
  key: string;
  isActive: boolean;
  targetGame: string; // package name, e.g. com.herogame.gplay.lastdayrulessurvival
  maxUses: number;
  usesCount: number;
  assignedTo: string; // User username this key belongs to
  deviceFingerprint: string; // Hardware footprint bound to this key
  createdBy: string; // Admin username
  createdAt: Date;
  expiresAt?: Date;
}

const keySchema = new Schema<IKey>({
  key: { type: String, required: true, unique: true, index: true },
  isActive: { type: Boolean, default: true },
  targetGame: { type: String, default: 'com.herogame.gplay.lastdayrulessurvival' },
  maxUses: { type: Number, default: 1 },
  usesCount: { type: Number, default: 0 },
  assignedTo: { type: String, default: '' },
  deviceFingerprint: { type: String, default: '' },
  createdBy: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  expiresAt: { type: Date }
});

export const Key = mongoose.model<IKey>('Key', keySchema);
export default Key;
