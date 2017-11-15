import collections
from clustering.agglomerative.agglomerative_cluster import AgglomerativeClusterPBeta
import numpy as np
from scipy.spatial.distance import minkowski
from clustering.common import get_weights, minkowski_center, weighed_minkowski
from clustering.cluster import Cluster

class AnomalousPatternInitializationPBeta:

    def __init__(self, data, p, beta):
        self._data = data
        self._p = p
        self._beta = beta
        self._origin = minkowski_center(self._data, self._p)
        self._clusters = []
        self._current_label = 0
        self._dim_rows = data.shape[0]
        self._dim_cols = data.shape[1]
        self._anomal_cluster = AgglomerativeClusterPBeta(self._current_label, self._data, self._p, self._beta)
        self._current_label+=1

    def tentative_centroid(self):
        self._anomal_cluster = Cluster()


def anomalous_cluster_p_beta(data, p, beta, tobj=None):
    data_copy = np.copy(data)
    centroids = []
    weights = []
    indices = np.arange(len(data))
    labels = np.zeros(len(data), dtype=int)
    V = data.shape[1]


    origin = minkowski_center(data, p)

    cluster_label = 0
    while len(data) > 1:
        x_to_origin = np.apply_along_axis(lambda x: minkowski(x, origin, p), axis=1, arr=data)
        w = np.full(fill_value=1 / V, shape=V)
        ct_index = np.argmax(x_to_origin)
        ct = data[ct_index]
        ct_queue = collections.deque([None, None, ct], maxlen=3)
        anomaly = np.full(len(data), False, dtype=bool)
        anomaly[ct_index] = True
        tent_w = np.full(fill_value=1 / V, shape=V)
        while not (np.array_equal(ct_queue[-1], ct_queue[-2]) or np.array_equal(ct_queue[-1], ct_queue[-3])):
            # tobj.plot(data, labels[indices], centroids, show_num=False)
            x_to_origin = np.apply_along_axis(lambda x: weighed_minkowski(x, origin, p, tent_w, beta), axis=1, arr=data)
            x_to_ct = np.apply_along_axis(lambda x: weighed_minkowski(x, ct, p, tent_w, beta), axis=1, arr=data)
            anomaly = x_to_ct < x_to_origin
            # normalcy = ~anomaly
            ct = minkowski_center(data[anomaly], p)
            tent_w = get_weights(data[anomaly], ct, p)
            ct_queue.append(ct)
        normalcy = ~anomaly
        centroids.append(ct)
        # centroids = []
        weights.append(w)
        data = data[normalcy]
        indices = indices[normalcy]
        cluster_label += 1
        labels[indices] = cluster_label
    if len(data) > 0:
        ct = minkowski_center(data, p)
        centroids.append(ct)
        weights.append(np.full(ct.shape, 1 / len(ct)))
    # tobj.plot(data_copy, labels, show_num=False, prefix="RESULT")
    return labels, np.array(centroids), np.array(weights)


if __name__ == "__main__":
    from tests.tools.plot import TestObject

    data = TestObject.load_data("ikmeans_test8.dat")
    tobj = TestObject('anomalous_cluster_p_beta')
    p, beta = 2, 2
    labels, centroids, weights = anomalous_cluster_p_beta(data, p, beta, tobj=tobj)
    tobj.plot(data, labels, centroids=centroeids, prefix="RESULT")
