const Q96 = 2 ** 96;

const state = {
  pool: null,
  totalShares: 0,
  totalLiquidity: 0,
  accumulatedFees: 0,
  holders: {}
};

const els = {
  token0: document.getElementById("token0"),
  token1: document.getElementById("token1"),
  tickLower: document.getElementById("tickLower"),
  tickUpper: document.getElementById("tickUpper"),
  depositOwner: document.getElementById("depositOwner"),
  deposit0: document.getElementById("deposit0"),
  deposit1: document.getElementById("deposit1"),
  redeemOwner: document.getElementById("redeemOwner"),
  redeemShares: document.getElementById("redeemShares"),
  metrics: document.getElementById("metrics"),
  ownership: document.getElementById("ownership"),
  log: document.getElementById("log")
};

const fmt = (n) => Number(n).toLocaleString(undefined, { maximumFractionDigits: 6 });

function totalVaultValue() {
  return state.totalLiquidity + state.accumulatedFees;
}

function sharePriceX96() {
  return state.totalShares === 0 ? Q96 : (totalVaultValue() * Q96) / state.totalShares;
}

function log(line) {
  const now = new Date().toLocaleTimeString();
  els.log.textContent = `[${now}] ${line}\n${els.log.textContent}`;
}

function refresh() {
  const value = totalVaultValue();
  const metrics = [
    ["Total Shares", fmt(state.totalShares)],
    ["Total Liquidity", fmt(state.totalLiquidity)],
    ["Accumulated Fees", fmt(state.accumulatedFees)],
    ["Vault Value", fmt(value)],
    ["Share Price X96", fmt(sharePriceX96())]
  ];

  els.metrics.innerHTML = metrics
    .map(([k, v]) => `<div><dt>${k}</dt><dd>${v}</dd></div>`)
    .join("");

  const holders = Object.entries(state.holders).sort((a, b) => b[1] - a[1]);
  const total = holders.reduce((acc, [, shares]) => acc + shares, 0);

  if (!holders.length || total === 0) {
    els.ownership.innerHTML = "<p>No shares minted yet.</p>";
    return;
  }

  els.ownership.innerHTML = holders
    .map(([owner, shares]) => {
      const pct = (shares / total) * 100;
      return `
        <div class="row">
          <span>${owner}</span>
          <div class="bar"><div class="fill" style="width:${pct}%"></div></div>
          <strong>${pct.toFixed(2)}%</strong>
        </div>`;
    })
    .join("");
}

document.getElementById("createPool").addEventListener("click", () => {
  state.pool = {
    token0: els.token0.value.trim(),
    token1: els.token1.value.trim(),
    tickLower: Number(els.tickLower.value),
    tickUpper: Number(els.tickUpper.value)
  };
  log(`Pool context created for ${state.pool.token0}/${state.pool.token1} [${state.pool.tickLower}, ${state.pool.tickUpper}]`);
});

document.getElementById("depositBtn").addEventListener("click", () => {
  const owner = els.depositOwner.value.trim();
  const amount0 = Number(els.deposit0.value);
  const amount1 = Number(els.deposit1.value);
  const depositValue = amount0 + amount1;

  if (!owner || depositValue <= 0) {
    return;
  }

  const vaultValueBefore = totalVaultValue();
  let sharesMinted = depositValue;

  if (state.totalShares > 0 && vaultValueBefore > 0) {
    sharesMinted = (depositValue * state.totalShares) / vaultValueBefore;
    sharesMinted = Math.max(sharesMinted, 1);
  }

  state.totalShares += sharesMinted;
  state.totalLiquidity += depositValue;
  state.holders[owner] = (state.holders[owner] || 0) + sharesMinted;

  log(`${owner} deposited ${fmt(depositValue)} value and minted ${fmt(sharesMinted)} shares`);
  refresh();
});

document.getElementById("redeemBtn").addEventListener("click", () => {
  const owner = els.redeemOwner.value.trim();
  const sharesBurned = Number(els.redeemShares.value);

  if (!owner || sharesBurned <= 0) {
    return;
  }

  const ownerShares = state.holders[owner] || 0;
  if (sharesBurned > ownerShares || state.totalShares === 0) {
    log(`Redeem rejected for ${owner}: insufficient shares`);
    return;
  }

  const value = (sharesBurned * totalVaultValue()) / state.totalShares;

  state.holders[owner] -= sharesBurned;
  state.totalShares -= sharesBurned;

  const fromLiquidity = Math.min(value, state.totalLiquidity);
  state.totalLiquidity -= fromLiquidity;
  state.accumulatedFees -= value - fromLiquidity;

  log(`${owner} redeemed ${fmt(sharesBurned)} shares for ${fmt(value)} value`);
  refresh();
});

refresh();
