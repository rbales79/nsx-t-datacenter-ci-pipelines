import os
import json


def create_tenant_edge_params():
    dns_domain = os.getenv('dns_domain_int')
    edge_specs = os.getenv('tenant_edge_clusters_int')
    tenant_edge_clusters = json.loads(edge_specs)

    with open('tenant_edges', 'w') as edge_output_file:
        edge_output_file.write('\n[tenant_edge_nodes]\n')
        for edge_cluster in tenant_edge_clusters:
            edge_ips = edge_cluster['edge_ips'].split(',')
            for i in range(len(edge_ips)):
                item_name = "%s-%s" % (edge_cluster['edge_hostname_prefix'], i+1)
                hostname = item_name + dns_domain
                transport_node_name = "%s-%s" % (edge_cluster['edge_transport_node_prefix'], i+1)
                edge_line = item_name + ' ip=' + edge_ips[i] + ' hostname=' + hostname
                edge_line += ' default_gateway=' + edge_cluster['edge_default_gateway']
                edge_line += ' prefix_length=' + str(edge_cluster['edge_ip_prefix_length'])
                edge_line += ' transport_node_name=' + transport_node_name
                params_to_write = ['edge_cli_password',
                                   'edge_root_password',
                                   'vc_datacenter_for_edge',
                                   'vc_cluster_for_edge',
                                   'vc_datastore_for_edge',
                                   'vc_management_network_for_edge',
                                   'vc_overlay_network_for_edge',
                                   'vc_uplink_network_for_edge']
                for param in params_to_write:
                    edge_line += ' %s=%s' % (param, edge_cluster[param])
                edge_output_file.write(edge_line + '\n')
            edge_output_file.write('\n')


def create_tenant_t0_params():
    t0_specs = os.getenv('tenant_t0s_int')
    tenant_t0s = json.loads(t0_specs)

    with open('tenant_t0s', 'w') as tenant_t0_ouput_file:
        tenant_t0_ouput_file.write('\n[tenant_t0s]\n')
        for t0 in tenant_t0s:
            t0_line = ''
            params_to_write = ['tier0_router_name',
                               'uplink_port_ip',
                               'uplink_port_subnet',
                               'uplink_next_hop_ip',
                               'uplink_port_ip_2',
                               'ha_vip',
                               'edge_cluster',
                               'is_tanent',
                               'BGP_as_number']
            for param in params_to_write:
                t0_line += ' %s=%s' % (param, t0[param])
            tenant_t0_ouput_file.write(t0_line + '\n')
        tenant_t0_ouput_file.write('\n')


def main():
    create_tenant_edge_params()
    create_tenant_t0_params()


if __name__ == '__main__':
    main()
