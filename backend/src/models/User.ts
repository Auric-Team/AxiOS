import mongoose, { Document, Schema } from 'mongoose';

export interface IUser extends Document {
  username: string;
  passwordHash: string;
  role: 'admin' | 'user';
  createdAt: Date;
  deviceFingerprint: string;
}

const userSchema = new Schema<IUser>({
  username: { type: String, required: true, unique: true, index: true },
  passwordHash: { type: String, required: true },
  role: { type: String, enum: ['admin', 'user'], default: 'user' },
  createdAt: { type: Date, default: Date.now },
  deviceFingerprint: { type: String, default: '' }
});

export const User = mongoose.model<IUser>('User', userSchema);
export default User;
