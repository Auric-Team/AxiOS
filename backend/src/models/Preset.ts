import mongoose, { Document, Schema } from 'mongoose';

export interface IPreset extends Document {
  package: string; // Target game package, e.g., com.herogame.gplay.lastdayrulessurvival
  name: string;    // Display name, e.g., Last Island of Survival
  createdAt: Date;
}

const presetSchema = new Schema<IPreset>({
  package: { type: String, required: true, unique: true, index: true },
  name: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});

export const Preset = mongoose.model<IPreset>('Preset', presetSchema);
export default Preset;
