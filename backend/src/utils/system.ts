import os from 'os';

export interface SystemInfo {
  platform: string;
  release: string;
  uptime: number;
  totalMemory: number;
  freeMemory: number;
  memoryUsagePercentage: number;
  cpuModel: string;
  cpuCores: number;
  loadAverage: number[];
}

/**
 * Reads real-time hardware diagnostics and OS metrics.
 */
export function getSystemInfo(): SystemInfo {
  const totalMemory = os.totalmem();
  const freeMemory = os.freemem();
  const memoryUsagePercentage = totalMemory > 0 
    ? parseFloat(((1 - freeMemory / totalMemory) * 100).toFixed(2)) 
    : 0;
  
  const cpus = os.cpus() || [];
  const cpuModel = cpus.length > 0 ? cpus[0].model : 'Unknown Hardware';
  
  // Returns 1, 5, and 15 min load averages. (Windows defaults to [0, 0, 0])
  const loadAverage = os.loadavg() || [0, 0, 0];

  return {
    platform: os.platform(),
    release: os.release(),
    uptime: os.uptime(),
    totalMemory,
    freeMemory,
    memoryUsagePercentage,
    cpuModel,
    cpuCores: cpus.length,
    loadAverage,
  };
}
