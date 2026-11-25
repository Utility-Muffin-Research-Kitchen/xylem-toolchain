// The C++ half of the smoke test: libstdc++, threads, and fmt.
#include <fmt/format.h>

#include <atomic>
#include <string>
#include <thread>
#include <vector>

int main()
{
	std::atomic<int> sum{0};
	std::vector<std::thread> threads;
	for (int i = 1; i <= 4; i++)
		threads.emplace_back([&sum, i] { sum += i; });
	for (auto &t : threads)
		t.join();
	std::string line = fmt::format("fmt {}.{}.{}, threads sum {}", FMT_VERSION / 10000,
		FMT_VERSION / 100 % 100, FMT_VERSION % 100, sum.load());
	fmt::print("{}\n", line);
	return sum == 10 ? 0 : 1;
}
