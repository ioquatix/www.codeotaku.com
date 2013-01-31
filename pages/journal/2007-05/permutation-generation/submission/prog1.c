// Please use g++ to compile these programs


#include <vector>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <algorithm>
#include <cstdlib>
#include <ctime>
#include <string>

using namespace std;

typedef vector<int> array_t;
typedef vector<array_t> results_t;

void printArray (const array_t &a) {
	for (unsigned j = 0; j < a.size(); ++j)
		cout << setw(4) << a[j] << (j+1 < a.size() ? ", " : "");
	
	cout << endl;
}

double system_time () {
	static struct timeval t;
	gettimeofday (&t, (struct timezone*)0);
	return ((double)t.tv_sec) + ((double)t.tv_usec / 1000000.0);
}

class AlgorithmBase {
protected:
	bool ignoreResults;
	vector<array_t> results;
		
public:
	AlgorithmBase () : ignoreResults(false) {
	}
	
	void setIgnoreResults (bool b) {
		ignoreResults = b;
	}
	
	bool getIgnoreResults () {
		return ignoreResults;
	}
	
	void addResult(const array_t &r) {
		if (!ignoreResults) {
			// Results are base 1
			results.push_back(array_t(r.begin() + 1, r.end()));
		}
	}
	
	void output () {
		for (unsigned i = 0; i < results.size(); ++i) {
			cout << setw(6) << i << ": ";
			
			printArray(results[i]);
		}
	}
	
	const vector<array_t>& getResults () {
		return results;
	}
	
	void resetResults () {
		results.resize(0);
	}
	
	virtual void generate () = 0;
	virtual const char * name () {
		return "Unnamed";
	}
};

class Algorithm5 : public AlgorithmBase {
protected:	
	const int n;
	vector<bool> used;
	array_t a;
	
	void perm(unsigned k) {		
		if (k <= n) {
			for (unsigned i = 1; i <= n; ++i) {
				if (!used[i]) {
					a[k] = i;
					used[i] = true;
					perm(k+1);
					used[i] = false;
				}
			}
		} else {
			addResult(a);
		}
	}
public:
	Algorithm5 (int _n) : n(_n) {
		a.resize(n+1);
		used.resize(n+1);
	}
	
	virtual void generate () {
		resetResults();
		perm(1);
	}
	
	virtual const char * name () {
		return "Slow Recursive";
	}
};

class Algorithm6 : public AlgorithmBase {
protected:	
	vector<array_t> results;
	const int n;
	array_t a;
	
	unsigned minimum (unsigned k) {
		unsigned j = 0, t = (unsigned)-1;
		
		for (unsigned i = k; i <= n; ++i) {
			if (a[i] < t && a[i] > a[k-1]) {
				j = i;
				t = a[i];
			}
		}
		
		return j;
	}
	
	void swap (unsigned i, unsigned j) {
		unsigned t = a.at(i);
		a[i] = a.at(j);
		a[j] = t;
	}
	
	void reverse (unsigned k) {		
		for (unsigned i = 0; i < (n-k+1) / 2; i += 1)
			swap(k+i, n-i);
	}
	
private:
	void perm(unsigned k) {
		int j;
		
		if (k < n) {
			for (unsigned i = k; i <= n; ++i) {				
				perm(k+1);
				
				if (i != n) {
					reverse(k+1);
					j = minimum(k+1);
					swap(k, j);
					addResult(a);
				}
			}
		}
	}
public:
	Algorithm6 (int _n) : n(_n) {
		a.resize(n+1);
	}
	
	virtual void generate () {
		resetResults();
		
		for (unsigned i = 0; i <= n; ++i)
			a[i] = i;
		
		addResult(a);
		perm(1);
	}
	
	virtual const char * name () {
		return "Faster Recursive";
	}
};

class Algorithm7 : public Algorithm6 {
public:
	Algorithm7 (int _n) : Algorithm6(_n) {
	
	}
	
	virtual void generate () {
		resetResults();
		unsigned i;
		
		for (i = 0; i <= n; ++i) a[i] = i;
		
		addResult(a);
		do {
			i = n;
			
			while (a[i-1] > a[i]) i -= 1;
			
			i -= 1;
			if (i > 0) {
				reverse(i+1);
				unsigned j = minimum(i+1);
				swap(i, j);
				addResult(a);
			}
		} while (i > 0);
	}
	
	virtual const char * name () {
		return "Iterative";
	}
};

class Algorithm8 : public AlgorithmBase {
protected:	
	const int n;
	array_t a, d, p;
	
	void move (int x) {
		int w = a[p[x]+d[x]];
		a.at(p[x]+d[x]) = x;
		a.at(p[x]) = w;
		p.at(w) = p[x];
		p.at(x) = p[x]+d[x]; 
	}
	
private:
	void nest(int k) { 		
		if (k <= n) {
			for (int i = 1; i <= k; i += 1) {
				nest(k+1);
				if (i < k) {
					move(k);
					addResult(a);
				}
			}
		
			d[k] = -d[k];
		}
	} 

public:
	Algorithm8 (int _n) : n(_n) {
		a.resize(n+1);
		d.resize(n+1);
		p.resize(n+1);
	}
	
	virtual void generate () {
		resetResults();
		
		for (int i = 1; i <= n; i += 1) {
			a[i] = i; 
			p[i] = i;
			d[i] = -1;
		}
		
		addResult(a);
		nest(2);
	}
	
	virtual const char * name () {
		return "Johnson-Trotter Recursive";
	}
};

#define O_MOVE 1
#define O_INNER 1

class Algorithm9 : public Algorithm8 {
protected:	
	array_t c, up;
	
#if O_MOVE
	inline int sign(int x) {
		return x < 0 ? -1 : 1;
	}
	
	void move (int x) {
		int dx, px = p[x];
		if (px < 0) {
			dx = -1;
			px *= -1;
		} else {
			dx = 1;
		}
		
		int w = a[px+dx];
		a.at(px+dx) = x;
		a.at(px) = w;
		
		p.at(w) = px * sign(p[w]);
		p.at(x) = (px+dx) * sign(p[x]);
	}
#endif
	
public:
	Algorithm9 (int _n) : Algorithm8(_n) {
		c.resize(n+1);
		up.resize(n+1);
	}
	
	virtual void generate () {
		resetResults();
		int i;
		
		for (i = 1; i <= n; i += 1) {
			a[i] = i;
			c[i] = 0;
			d[i] = -1;
#if O_MOVE
			p[i] = -i;
#else
			p[i] = i;
#endif
			up[i] = i;
		}
		
		addResult(a);
				
		do {
			i = up[n];
			
#if O_INNER
			if (i == n) {
				for (unsigned w = 1; w < n; w += 1) {
					move(i);
					addResult(a);
				}
				
				up[n] = up[n - 1];
				up[n-1] = n - 1;
#if O_MOVE
				p[n] = -p[n];
#else
				d[n] = -d[n];
#endif
				
				continue;
			}
#endif
			
			up[n] = n;
			
			if (i > 1) {
				c[i] = c[i] + 1;
				move(i);
				addResult(a);
			}
			
			if (c[i] == i-1) {
				up[i] = up[i-1];
				up[i-1] = i - 1;
#if O_MOVE
				p[i] = -p[i];
#else
				d[i] = -d[i];
#endif
				c[i] = 0;
			}
			
		} while (i != 1);
	}
	
	virtual const char * name () {
		return "Johnson-Trotter Iterative";
	}
};

#if !defined(DEFAULT_ALGORITHM)
#define DEFAULT_ALGORITHM 5
#endif

#include "sort.c"

const char* g_programName = NULL;
void usage () {
	cerr << "Usage: " << g_programName << " [algorithm-id = 5,6,7,8,9] [order=1...n] [options]" << endl;
	cerr << "\t-t\t Print out time information" << endl;
	cerr << "\t-s\t Test sorting algorithm" << endl;
	cerr << "The above modes are mutually exclusive" << endl;
	cerr << "If no arguments are provided, default algorithm is used. Input size on STTDIN." << endl;
}

int getInt (const char *c) {
	stringstream s;
	s << c;
	int t;
	s >> t;
	
	return t;
}

int main (int argc, const char * argv[]) {
	g_programName = argv[0];
	
	const int tfactor = 1;
	
	stringstream s;
	bool testSort = false, testTime = false;
	int c = 0, aid = 0;
	
	if (argc <= 1) {
		// Read in data assignemnt style (from stdin)
		aid = DEFAULT_ALGORITHM;
		cin >> c;
	} else {
		// Read in data from args (convenience)
		aid = getInt(argv[1]);
		c = getInt(argv[2]);
	}
	
	// Make sure we have valid data
	if (c == 0 || aid == 0) {
		cerr << "*** Invalid algorithm id = " << aid << " or order " << c << endl;
		usage();
		exit(6);
	}
	
	// Scan for the run mode
	for (unsigned i = 3; i < argc; i += 1) {
		if (argv[i][0] == '-') {
			switch (argv[i][1]) {
				case 't':
					testTime = true; break;
				case 's':
					testSort = true; break;
				default:
					cerr << "*** Invalid option: " << argv[i] << endl;
					usage();
					exit(7);
			}
		} else {
			cerr << "*** Invalid option: " << argv[i] << endl;
			usage();
			exit(7);
		}
	}
	
	#ifdef TEST_TIME
	testTime = true;
	testSort = false;
	#endif
	
	if (testTime && testSort) {
		cerr << "*** Sort test and time test are mutually exclusive" << endl;
		usage();
		exit(8);
	}
		
	AlgorithmBase *algo = NULL;
	switch (aid) {
		case 5: algo = new Algorithm5(c); break;
		case 6: algo = new Algorithm6(c); break;
		case 7: algo = new Algorithm7(c); break;
		case 8: algo = new Algorithm8(c); break;
		case 9: algo = new Algorithm9(c); break;
		default:
			cerr << "*** Invalid algorithm: " << aid << endl;
			usage();
			exit(9);
	};
	
	if (testTime) {
		algo->setIgnoreResults(true);
	}
	
	cout << "Generating permutations using algorithm " << aid << ": " << algo->name() << " size " << c << endl;
	
	unsigned times = 1;

	if (testTime) {
		int texp = (14 - c);
		texp *= texp;
		texp /= c;
		
		times = max(texp, 1);
		times *= times * tfactor;
		cout << "Running " << times << " times and averaging result..." << endl;
	}
	
	double start, end;
	start = system_time();
	
	for (unsigned i = 0; i < times; i += 1)
		algo->generate();
	
	end = system_time();
	
	if (!testTime) {
		algo->output();
	}
	
	cout << "Time: " << (end - start) / (double)times << endl;
	
	if (testSort && !algo->getIgnoreResults()) {	
		vector<array_t> results (algo->getResults());
		
		// Random data to permutate
		array_t data; data.reserve(c);
		for (unsigned i = 0; i < c; i += 1)
			data.push_back(rand() % 1000);
		
		// Test sorting algorithm
		for (unsigned i = 0; i < results.size(); i += 1) {
			cout << "data    "; printArray(data);
			cout << "permute "; printArray(results[i]);
			
			array_t p = permutate(results[i], data);
			
			cout << "permuted"; printArray(p);
					
			sort(p);
			
			cout << "sorted  "; printArray(p);
			
			if (!sorted(p)) {
				cout << "*** Sort failed!!" << endl;
				break;
			}
			
			if (i < results.size() - 1) 
				cout << endl;
		}
	}
	
	
	delete algo;
	
	return 0;
}
