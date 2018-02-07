from clustering.common import minkowski_center
import numpy as np
from clustering.cluster_structure import ClusterStructure
from clustering.agglomerative.utils.agglomerative_cluster_structure import AgglomerativeClusterStructure


class AWardPBClusterStructure(AgglomerativeClusterStructure):
    """Cluster structure for A-Ward agglomerative clustering with p and beta parameters"""

    class Cluster(ClusterStructure.Cluster):
        """Cluster for A-Ward agglomerative clustering with p and beta parameters
        """

        def __init__(self, cluster_structure, points_indices, centroid=None, weights=None):
            """Constructor for cluster. Basically the cluster structure generates the cluster, so
            the constructor should be called only from ClusterStructure's methods.

            :param AWardPBClusterStructure cluster_structure: a cluster structure which generates the cluster
            :param numpy.array points_indices: [points_in_cluster x 1] the indices of points that forms the cluster.
            Indices are specified based on initial data set."""
            super().__init__(cluster_structure, points_indices)
            p, beta = cluster_structure.p, cluster_structure.beta
            cluster_points = cluster_structure.data[self._points_indices]

            if centroid is None:
                centroid = minkowski_center(cluster_points, p)
            self._centroid = centroid
            if weights is None:
                # set weights (as per 7)
                D = np.sum(np.abs(cluster_points - self.centroid) ** p, axis=0).astype(np.float64)
                if beta != 1:
                    with np.errstate(divide='ignore', invalid='ignore'):
                        D += 0.01
                        denominator = ((D ** (1 / (beta - 1))) * np.sum((np.float64(1.0) / D) ** (1 / (beta - 1))))
                    isnan = np.isnan(denominator)
                    if np.any(isnan):
                        weights = isnan.astype(int) / np.sum(isnan)
                    else:
                        weights = np.float64(1.0) / denominator
                else:
                    sh = (cluster_structure.dim_cols,)
                    if np.allclose(D - D[0], np.zeros(sh)):
                        weights = np.ones(sh) / sh[0]
                    else:
                        weights = np.zeros(shape=sh)
                        weights[np.argmin(D)] = 1
            self._weights = weights
            assert self._weights.shape == (cluster_structure.dim_cols,)
            assert np.abs(np.sum(self._weights) - 1) < 0.0001

        @property
        def weights(self):
            """Weights of this cluster

            :return: current weights of cluster
            """
            return self._weights

        def __str__(self):
            res = "AWard_pb Cluster"
            return res

    def __init__(self, data, p, beta):
        """
        :param float p: Minkowski power
        :param float beta: power of the weights"""
        super().__init__(data)
        self._p = p
        self._beta = beta
        self._equal_weights = np.ones(shape=(self.dim_cols,)) / self.dim_cols

    def dist_point_to_point(self, point1, point2, cluster_of_point1=None):
        """Calculates distance from one point to another.
        The distance is equal to squared euclidean distance between this points.

        :param Cluster cluster_of_point1: a cluster of first point
        :param np.array point1: [features] coordinates of one point
        :param np.array point2: [features] coordinates of another point
        :returns distance according current weights"""
        if cluster_of_point1 is None:
            weights = self._equal_weights
        else:
            weights = cluster_of_point1.weights
        return np.sum((weights ** self.beta) * (np.abs(point1 - point2) ** self.p)) ** (1 / self.p)

    def dist_point_to_cluster(self, point, cluster):
        """Calculates distance from specified point to cluster centroid.
        The distance is calculated according current weights.

        :param np.array point: [features] coordinates of the point
        :param Cluster cluster: a cluster to calculate distance
        :returns distance according current weights"""
        return self.dist_point_to_point(point, cluster.centroid, cluster)

    def dist_cluster_to_cluster(self, cluster1, cluster2):
        """WardPB distance between this cluster and specified one
        :param Cluster cluster1: first cluster
        :param Cluster cluster2: second cluster
        :returns distance between clusters
        """
        p = self.p
        beta = self.beta
        na, nb = cluster1.power, cluster2.power
        wa, wb = cluster1.weights, cluster2.weights
        delta = np.abs(cluster1.centroid - cluster2.centroid)
        weight_multiplier = ((wa + wb) / 2) ** beta
        distance = ((na * nb) / (na + nb)) * (sum(weight_multiplier * (delta ** p)))
        return distance

    @property
    def p(self):
        return self._p

    @property
    def beta(self):
        return self._beta

    def merge(self, cluster1, cluster2):
        """Merges two clusters into one."""
        p, beta = self._p, self._beta
        self.del_cluster(cluster1)
        self.del_cluster(cluster2)

        assert not (cluster1 == cluster2)  # doesn't work?

        new_points_indices = np.append(cluster1.points_indices, cluster2.points_indices)
        new_points = self._data[new_points_indices]
        new_centroid = minkowski_center(new_points, self.p)

        D = np.sum(np.abs(new_points - new_centroid) ** p, axis=0).astype(np.float64)
        if beta != 1:
            with np.errstate(divide='ignore', invalid='ignore'):
                D += 0.0001
                denominator = ((D ** (1 / (beta - 1))) * np.sum((np.float64(1.0) / D) ** (1 / (beta - 1))))
            isnan = np.isnan(denominator)
            if np.any(isnan):
                new_weights = isnan.astype(int) / np.sum(isnan)
            else:
                new_weights = np.float64(1.0) / denominator
        else:
            sh = new_centroid.shape
            if np.allclose(D - D[0], np.zeros(sh)):
                new_weights = np.ones(sh) / sh[0]
            else:
                new_weights = np.zeros(shape=sh)
                new_weights[np.argmin(D)] = 1
        new_cluster = self.Cluster(self, new_points_indices, centroid=new_centroid, weights=new_weights)
        self.add_cluster(new_cluster)
        return new_cluster
