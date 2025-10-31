export const fillUsageValues = (usage) => {
  const {
    creditsUsed,
    totalCredits,
    monthlyCommitmentCreditsUsed,
    oneTimeCreditsUsed,
    overageCreditsUsed,
  } = usage ?? {};

  return {
    creditsUsed: creditsUsed ?? 0,
    totalCredits: totalCredits ?? 0,
    monthlyCommitmentCreditsUsed: monthlyCommitmentCreditsUsed ?? 0,
    oneTimeCreditsUsed: oneTimeCreditsUsed ?? 0,
    overageCreditsUsed: overageCreditsUsed ?? 0,
  };
};
