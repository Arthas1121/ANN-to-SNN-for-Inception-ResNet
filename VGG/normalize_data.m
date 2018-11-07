function [net,factor_log]=normalize_data(net,percentile)

% net.layers{l}.a ��ѵ����ǰ������¼����Ԫ����ֵ

previous_factor=1;
factor_log=zeros(1,numel(net.layers));

for l=1:numel(net.layers)
	if strcmp(net.layers{l}.type,'conv')
		
		% ����ÿ������Ȩ��
		max_weight=max(max(max(max(net.layers{l}.weights{1}))));
		max_bias=max(net.layers{l}.weights{2});
		max_weight=max(max_weight,max_bias);
		fprintf('The max value of weight in layer %d is:%.4f\n',l, max_weight);

		if percentile==100
			% ����ÿ���������ֵ
			max_activation=max(max(max(max(net.layers{l}.a))));
		else
			temp=reshape(net.layers{l}.a,1,[]);
			max_activation=prctile(temp,percentile);
		end
		fprintf('The max value of activation in layer %d is:%.4f\n',l, max_activation);

		scale_factor=max(max_weight,max_activation);
		current_factor=scale_factor/previous_factor;

		% weights and biases ��Ҫ���� normalization
		net.layers{l}.weights{1}=net.layers{l}.weights{1}/current_factor;
		net.layers{l}.weights{2}=net.layers{l}.weights{2}/scale_factor;
        
		factor_log(l)=1/current_factor;
		previous_factor=scale_factor;

	end
end


