
package fuzzwavelet

import (
	"github.com/perlin-network/wavelet"
)

func Fuzz(data []byte) int {
	wavelet.ParseTransferTransaction(data);
	wavelet.ParseStakeTransaction(data);
	wavelet.ParseContractTransaction(data);
	wavelet.ParseBatchTransaction(data);
	return 1
}
