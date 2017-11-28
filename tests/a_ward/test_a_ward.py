import numpy as np

from clustering.agglomerative.algorithms.a_ward import AWard
from tests.tools import transformation_exists
from sklearn.cluster import AgglomerativeClustering as sklearn_clustering

DATA_DIR = "/home/eremeykin/d_disk/projects/Clustering/ect/tests/shared/data/"


def test_symmetric_16points():
    data = np.loadtxt('{}symmetric_15points.pts'.format(DATA_DIR))
    run_a_ward = AWard(data, labels=np.arange(0, len(data), dtype=int), k_star=5)
    result = run_a_ward()
    actual = np.loadtxt('{}symmetric_15points.lbs'.format(DATA_DIR), dtype=int)
    assert transformation_exists(actual, result)


def test_iris():
    data = np.loadtxt('{}iris.pts'.format(DATA_DIR))
    run_a_ward = AWard(data, labels=np.arange(0, len(data), dtype=int), k_star=3)
    result = run_a_ward()
    # compare with sklearn implementation
    model = sklearn_clustering(n_clusters=3)
    model.fit(data)
    actual = model.labels_
    assert transformation_exists(actual, result)

def test_500_random():
    data = np.loadtxt('{}data500ws.pts'.format(DATA_DIR))
    run_a_ward = AWard(data, np.arange(0, len(data), dtype=int), 3)
    result = run_a_ward()
    # compare with sklearn implementation
    model = sklearn_clustering(n_clusters=3)
    model.fit(data)
    actual = model.labels_
    assert transformation_exists(actual, result)
