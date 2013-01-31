
void quicksort(array_t &v, unsigned left, unsigned right) {
	if (right > left + 1) {
		int pivot = v[left];
		int l = left + 1, r = right;
		
		while (l < r) {
			if (v[l] < pivot)
				l += 1;
			else
				std::swap(v[l], v[--r]);
		}
		
		swap(v[--l], v[left]);
		quicksort(v, left, l);
		quicksort(v, r, right);
	}
}

void sort (array_t &v) {
	quicksort(v, 0, v.size());
}

bool sorted (array_t &v) {
	int prev = v[0];
	
	for (unsigned i = 1; i < v.size(); i += 1) {
		if (v[i] < prev)
			return false;
		
		prev = v[i];
	}
	
	return true;
}

array_t permutate(array_t &p, array_t &d) {
	array_t r;
	r.reserve(d.size());
	
	for (unsigned i = 0; i < p.size(); i += 1) {
		r.push_back(d[p[i]-1]);
	}
	
	return r;
}
