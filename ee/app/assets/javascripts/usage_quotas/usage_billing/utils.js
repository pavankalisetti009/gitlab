export const fillUsageValues = (usage) => {
  const {
    creditsUsed,
    totalCredits,
    monthlyCommitmentCreditsUsed,
    monthlyWaiverCreditsUsed,
    overageCreditsUsed,
  } = usage ?? {};

  return {
    creditsUsed: creditsUsed ?? 0,
    totalCredits: totalCredits ?? 0,
    monthlyCommitmentCreditsUsed: monthlyCommitmentCreditsUsed ?? 0,
    monthlyWaiverCreditsUsed: monthlyWaiverCreditsUsed ?? 0,
    overageCreditsUsed: overageCreditsUsed ?? 0,
  };
};
