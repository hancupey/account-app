export function formatAmount(amount: number): string {
  return amount.toFixed(2);
}

export function parseAmount(text: string): number {
  const value = Number.parseFloat(text.trim());
  if (Number.isNaN(value) || value <= 0) {
    return 0;
  }
  return value;
}
